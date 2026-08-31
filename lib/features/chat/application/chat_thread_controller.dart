import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/network/bloom_api_client.dart';
import '../../../core/network/bloom_api_exception.dart';
import '../../../core/network/bloom_field_parsers.dart';
import '../domain/chat_message.dart';
import '../domain/chat_thread_state.dart';
import 'talk_list_controller.dart';

part 'chat_thread_controller.g.dart';

const _kPollInterval = Duration(seconds: 3);

@riverpod
class ChatThreadController extends _$ChatThreadController {
  bool _disposed = false;

  @override
  Future<ChatThreadState> build(int partnerId) async {
    final client = ref.read(bloomApiClientProvider);

    try {
      await client.callApi('setReadFlag', {'target_id': partnerId});
      ref.invalidate(talkListControllerProvider);
    } catch (_) {
      // 既読化に失敗しても画面表示は継続する(未読バッジが残るだけ)。
    }

    final timer = Timer.periodic(_kPollInterval, (_) => _poll());
    ref.onDispose(() {
      _disposed = true;
      timer.cancel();
    });

    final userDataFuture = client.callApi('getUserData', {});
    final messagesFuture = _fetchMessages();
    final userData = await userDataFuture;
    final messages = await messagesFuture;
    final balance = asBloomInt((userData['user_data'] as Map<String, dynamic>)['balance']);
    return ChatThreadState(balance: balance, messages: messages);
  }

  Future<List<ChatMessage>> _fetchMessages() async {
    final data = await ref.read(bloomApiClientProvider).callApi('getMailLog', {'target_id': partnerId});
    final mailLog = (data['mail_log'] as List<dynamic>?) ?? const [];
    return mailLog.map((entry) => ChatMessage.fromMailLogEntry(entry as Map<String, dynamic>)).toList();
  }

  Future<void> _poll() async {
    if (_disposed) return;
    try {
      final messages = await _fetchMessages();
      if (_disposed) return;
      final current = state.value;
      if (current == null) return;
      state = AsyncData(ChatThreadState(balance: current.balance, messages: messages));
    } catch (_) {
      // ポーリングの一時的な失敗は無視し、前回の状態を表示し続ける。
    }
  }

  /// 送信中もメッセージ一覧を消さないよう、mainのAsyncValueをローディングに
  /// せず、成功時のみ`state`を更新する([GachaController.likeCandidate]と
  /// 同じ方針)。失敗時は例外を投げるので、呼び出し元(画面)が処理する。
  Future<void> sendMessage(String body) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty) return;

    final data = await ref.read(bloomApiClientProvider).callApi('sendMail', {'to_id': partnerId, 'body': trimmed});
    _applySendResult(data, 'sendMail');
  }

  /// [base64DataUri]は`data:image/xxx;base64,...`形式
  /// ([ProfileController.uploadPhoto]と同じ形式)。
  Future<void> sendImage(String base64DataUri) async {
    final data = await ref
        .read(bloomApiClientProvider)
        .callApi('sendImgMail', {'to_id': partnerId, 'image': base64DataUri});
    _applySendResult(data, 'sendImgMail');
  }

  /// [base64DataUri]は`data:audio/m4a;base64,...`形式。拡張子は
  /// `Class_File.php::saveBase64Audio`がdata URIから読み取る
  /// (`wav`/`m4a`/`mp3`のみ許可、それ以外は`wav`扱いになる)。
  Future<void> sendAudio(String base64DataUri) async {
    final data = await ref
        .read(bloomApiClientProvider)
        .callApi('sendAudioMail', {'to_id': partnerId, 'audio': base64DataUri});
    _applySendResult(data, 'sendAudioMail');
  }

  /// KNOWN QUIRK(bloom_api_client.dartのコメント参照): 残高不足時も
  /// result: '1'のまま返り、data.error_detailだけがセットされる。
  void _applySendResult(Map<String, dynamic> data, String executeFunction) {
    final errorDetail = data['error_detail'] as String?;
    if (errorDetail != null) {
      throw BloomApiException(errorDetail, executeFunction: executeFunction);
    }

    final mailLog = (data['mail_log'] as List<dynamic>?) ?? const [];
    final messages = mailLog.map((entry) => ChatMessage.fromMailLogEntry(entry as Map<String, dynamic>)).toList();
    final balance = asBloomInt((data['user_data'] as Map<String, dynamic>)['balance']);
    state = AsyncData(ChatThreadState(balance: balance, messages: messages));
    ref.invalidate(talkListControllerProvider);
  }

  /// 受信した画像を開く(`mail_id`単位で初回のみ課金、2回目以降は無料——
  /// バックエンド側`Mail::existImageDisplayLog`が判定する)。「既に開いたか」
  /// はサーバーから返らないため、呼び出し元(画面)がスレッドを開いている間
  /// だけローカルに憶えておく方針とする。
  Future<void> viewImage(int mailId) => _chargeOnFirstOpen(mailId, 'lookImgMail');

  /// 受信した音声を再生する(`mail_id`単位で初回のみ課金——
  /// [viewImage]の`existAudioPlayLog`版。同じくローカルに憶えておく方針)。
  Future<void> playAudio(int mailId) => _chargeOnFirstOpen(mailId, 'playAudioMail');

  /// `lookImgMail`/`playAudioMail`は同じ形状(`mail_id`+`target_id`を渡し、
  /// `user_data`(更新済み残高)のみが返る)なので処理を共用する。
  Future<void> _chargeOnFirstOpen(int mailId, String executeFunction) async {
    final data = await ref
        .read(bloomApiClientProvider)
        .callApi(executeFunction, {'mail_id': mailId, 'target_id': partnerId});

    final errorDetail = data['error_detail'] as String?;
    if (errorDetail != null) {
      throw BloomApiException(errorDetail, executeFunction: executeFunction);
    }

    final current = state.value;
    if (current == null) return;
    final balance = asBloomInt((data['user_data'] as Map<String, dynamic>)['balance']);
    state = AsyncData(ChatThreadState(balance: balance, messages: current.messages));
  }
}
