import '../../../core/network/bloom_field_parsers.dart';

/// `getMailLog`の1件分。画像・音声に対応。画像/音声メッセージは
/// `imageUrl`/`audioUrl`が非null——サーバー側が`body`に固定文言
/// ("画像送信"/"音声送信")を入れているため、表示時はそちらを優先する。
class ChatMessage {
  const ChatMessage({
    required this.mailId,
    required this.fromId,
    required this.body,
    required this.sendDate,
    required this.imageUrl,
    required this.audioUrl,
  });

  final int mailId;
  final int fromId;
  final String body;
  final String sendDate;
  final String? imageUrl;
  final String? audioUrl;

  factory ChatMessage.fromMailLogEntry(Map<String, dynamic> entry) => ChatMessage(
    mailId: asBloomInt(entry['mail_id']),
    fromId: asBloomInt(entry['from_id']),
    body: (entry['body'] as String?) ?? '',
    sendDate: (entry['send_date'] as String?) ?? '',
    imageUrl: resolveBloomAssetUrl(entry['img_path']),
    audioUrl: resolveBloomAssetUrl(entry['audio_path']),
  );
}
