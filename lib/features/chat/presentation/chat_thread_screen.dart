import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../../../core/media/image_orientation.dart';
import '../../../core/network/bloom_api_exception.dart';
import '../application/chat_thread_controller.dart';
import '../application/talk_list_controller.dart';
import '../domain/chat_message.dart';
import '../domain/chat_thread_state.dart';

/// 個別チャットスレッド画面。テキスト+画像+音声に対応
/// ([stage5-chat](../../../../.scratch/stage5-chat/map.md)で決定)。開いている
/// 間は数秒間隔で新着メッセージをポーリングする(トークの相手表示名・写真は
/// [talkListControllerProvider]のキャッシュ済みデータから探す——
/// [MatchCelebrationScreen]と同じ方針)。
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({super.key, required this.partnerId});

  final int partnerId;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _textController = TextEditingController();
  bool _isSending = false;

  // 「画像を開いた/音声を再生したか」はサーバーが返さない(既読・再生ログは
  // 別テーブルでsystem_id×mail_id単位、レスポンスに含まれない)ため、
  // スレッドを開いている間だけローカルに憶えておく——画面を閉じて開き直すと
  // また隠れた状態に戻る(細かいUXの割り切り、
  // [stage5-chat/issues/04](../../../../.scratch/stage5-chat/issues/04-image-messages.md)/
  // [05](../../../../.scratch/stage5-chat/issues/05-audio-messages.md)参照)。
  final Set<int> _revealedImageMailIds = {};
  final Set<int> _revealingImageMailIds = {};
  final Set<int> _unlockedAudioMailIds = {};
  final Set<int> _unlockingAudioMailIds = {};

  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordingElapsed = Duration.zero;
  Timer? _recordingTicker;

  final _audioPlayer = AudioPlayer();
  int? _playingMailId;
  StreamSubscription<void>? _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();
    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _playingMailId = null);
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _recordingTicker?.cancel();
    _audioRecorder.dispose();
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _textController.text;
    if (body.trim().isEmpty || _isSending) return;

    setState(() => _isSending = true);
    try {
      await ref.read(chatThreadControllerProvider(widget.partnerId).notifier).sendMessage(body);
      _textController.clear();
    } catch (e) {
      if (!mounted) return;
      final message = e is BloomApiException ? e.errorDetail : 'メッセージの送信に失敗しました。もう一度お試しください。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _pickAndSendImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1440,
      maxHeight: 1440,
      imageQuality: 85,
    );
    if (picked == null || _isSending) return;

    setState(() => _isSending = true);
    try {
      final bytes = await picked.readAsBytes();
      final dataUri = 'data:image/jpeg;base64,${base64Encode(normalizeJpegOrientation(bytes))}';
      await ref.read(chatThreadControllerProvider(widget.partnerId).notifier).sendImage(dataUri);
    } catch (e) {
      if (!mounted) return;
      final message = e is BloomApiException ? e.errorDetail : '画像の送信に失敗しました。もう一度お試しください。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _revealImage(int mailId) async {
    if (_revealingImageMailIds.contains(mailId)) return;
    setState(() => _revealingImageMailIds.add(mailId));
    try {
      await ref.read(chatThreadControllerProvider(widget.partnerId).notifier).viewImage(mailId);
      if (!mounted) return;
      setState(() {
        _revealingImageMailIds.remove(mailId);
        _revealedImageMailIds.add(mailId);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _revealingImageMailIds.remove(mailId));
      final message = e is BloomApiException ? e.errorDetail : '画像の表示に失敗しました。もう一度お試しください。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _startRecording() async {
    if (_isSending || _isRecording) return;
    if (!await _audioRecorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('マイクの使用を許可してください。')));
      return;
    }

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/chat_audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _recordingElapsed = Duration.zero;
    });
    _recordingTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _recordingElapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _cancelRecording() async {
    _recordingTicker?.cancel();
    _recordingTicker = null;
    await _audioRecorder.cancel();
    if (mounted) setState(() => _isRecording = false);
  }

  Future<void> _stopRecordingAndSend() async {
    _recordingTicker?.cancel();
    _recordingTicker = null;
    final path = await _audioRecorder.stop();
    if (mounted) setState(() => _isRecording = false);
    if (path == null) return;

    setState(() => _isSending = true);
    final file = File(path);
    try {
      final bytes = await file.readAsBytes();
      final dataUri = 'data:audio/m4a;base64,${base64Encode(bytes)}';
      await ref.read(chatThreadControllerProvider(widget.partnerId).notifier).sendAudio(dataUri);
    } catch (e) {
      if (!mounted) return;
      final message = e is BloomApiException ? e.errorDetail : '音声の送信に失敗しました。もう一度お試しください。';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isSending = false);
      try {
        await file.delete();
      } catch (_) {
        // 一時ファイルの削除失敗は送信結果に影響しないので無視する。
      }
    }
  }

  Future<void> _toggleAudio(ChatMessage message, {required bool unlocked}) async {
    final mailId = message.mailId;

    if (_playingMailId == mailId) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _playingMailId = null);
      return;
    }

    if (!unlocked) {
      setState(() => _unlockingAudioMailIds.add(mailId));
      try {
        await ref.read(chatThreadControllerProvider(widget.partnerId).notifier).playAudio(mailId);
        if (!mounted) return;
        setState(() {
          _unlockingAudioMailIds.remove(mailId);
          _unlockedAudioMailIds.add(mailId);
        });
      } catch (e) {
        if (!mounted) return;
        setState(() => _unlockingAudioMailIds.remove(mailId));
        final errorMessage = e is BloomApiException ? e.errorDetail : '音声の再生に失敗しました。もう一度お試しください。';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage)));
        return;
      }
    }

    await _audioPlayer.play(UrlSource(message.audioUrl!));
    if (mounted) setState(() => _playingMailId = mailId);
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final threadAsync = ref.watch(chatThreadControllerProvider(widget.partnerId));
    final partnerName = _findPartnerName();

    return Scaffold(
      appBar: AppBar(title: Text(partnerName ?? 'チャット')),
      body: SafeArea(
        child: threadAsync.when(
          data: (thread) => _buildContent(context, thread),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildError(context, error),
        ),
      ),
    );
  }

  String? _findPartnerName() {
    final talks = ref.watch(talkListControllerProvider).value;
    if (talks == null) return null;
    final matching = talks.where((t) => t.targetId == widget.partnerId);
    return matching.isEmpty ? null : matching.first.targetName;
  }

  Widget _buildContent(BuildContext context, ChatThreadState thread) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text('${thread.balance} pt', style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        Expanded(child: _buildMessageList(context, thread.messages)),
        const Divider(height: 1),
        _buildComposer(),
      ],
    );
  }

  Widget _buildMessageList(BuildContext context, List<ChatMessage> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'まだメッセージがありません。最初のメッセージを送ってみましょう。',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
    }
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      itemBuilder: (context, index) => _buildBubble(context, messages[messages.length - 1 - index]),
    );
  }

  Widget _buildBubble(BuildContext context, ChatMessage message) {
    final isMine = message.fromId != widget.partnerId;
    final colorScheme = Theme.of(context).colorScheme;
    final isImage = message.imageUrl != null;
    final isAudio = message.audioUrl != null;
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: isImage ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isImage ? null : (isMine ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest),
          borderRadius: BorderRadius.circular(12),
        ),
        child: isImage
            ? _buildImageContent(context, message, isMine)
            : isAudio
            ? _buildAudioContent(context, message, isMine)
            : Text(message.body),
      ),
    );
  }

  Widget _buildAudioContent(BuildContext context, ChatMessage message, bool isMine) {
    // 自分が送った音声は課金対象ではないので常に再生できる。
    final unlocked = isMine || _unlockedAudioMailIds.contains(message.mailId);
    final isUnlocking = _unlockingAudioMailIds.contains(message.mailId);
    final isPlaying = _playingMailId == message.mailId;

    return SizedBox(
      width: 160,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isUnlocking)
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
          else
            IconButton(
              padding: EdgeInsets.zero,
              onPressed: () => _toggleAudio(message, unlocked: unlocked),
              icon: Icon(isPlaying ? Icons.stop_circle : Icons.play_circle_fill, size: 32),
            ),
          const SizedBox(width: 4),
          Flexible(child: Text(unlocked ? 'ボイスメッセージ' : 'タップして再生', overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildImageContent(BuildContext context, ChatMessage message, bool isMine) {
    // 自分が送った画像は課金対象ではないので常にそのまま表示する。
    final revealed = isMine || _revealedImageMailIds.contains(message.mailId);
    if (revealed) {
      return Image.network(message.imageUrl!, fit: BoxFit.cover, width: 200, height: 200);
    }

    final isRevealing = _revealingImageMailIds.contains(message.mailId);
    return InkWell(
      onTap: isRevealing ? null : () => _revealImage(message.mailId),
      child: SizedBox(
        width: 200,
        height: 200,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: isRevealing
                ? const CircularProgressIndicator()
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.image_outlined, size: 32),
                      SizedBox(height: 4),
                      Text('タップして画像を表示'),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildComposer() {
    if (_isRecording) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            IconButton(onPressed: _cancelRecording, icon: const Icon(Icons.close)),
            Expanded(
              child: Row(
                children: [
                  Icon(Icons.fiber_manual_record, color: Theme.of(context).colorScheme.error, size: 16),
                  const SizedBox(width: 8),
                  Text(_formatDuration(_recordingElapsed)),
                ],
              ),
            ),
            IconButton(onPressed: _isSending ? null : _stopRecordingAndSend, icon: const Icon(Icons.send)),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          IconButton(onPressed: _isSending ? null : _pickAndSendImage, icon: const Icon(Icons.image_outlined)),
          IconButton(onPressed: _isSending ? null : _startRecording, icon: const Icon(Icons.mic_none)),
          Expanded(
            child: TextField(
              controller: _textController,
              enabled: !_isSending,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'メッセージを入力', border: OutlineInputBorder()),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(onPressed: _isSending ? null : _send, icon: const Icon(Icons.send)),
        ],
      ),
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    final message = error is BloomApiException ? error.errorDetail : '通信状態を確認してください。';
    return Center(child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)));
  }
}
