import '../../../core/network/bloom_field_parsers.dart';

/// `getMailListForMatching`の1件分——トーク一覧の1行分のデータ。
///
/// `MailApi::getMailListForMatching`は、マッチ済みだが未送信のトークも
/// 含めて返す(`body`は空文字、`print_send_date`はマッチ成立日時)。
/// `target_alias`は運営が管理する疑似キャラクター向けの別名で、
/// 通常のマッチ相手では null。
class TalkSummary {
  const TalkSummary({
    required this.targetId,
    required this.targetName,
    required this.photoUrl,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  final int targetId;
  final String targetName;
  final String? photoUrl;
  final String lastMessage;
  final String lastMessageAt;
  final int unreadCount;

  factory TalkSummary.fromMailListEntry(Map<String, dynamic> entry) {
    final alias = entry['target_alias'] as String?;
    final name = (alias != null && alias.isNotEmpty) ? alias : ((entry['target_name'] as String?) ?? '');
    return TalkSummary(
      targetId: asBloomInt(entry['target_id']),
      targetName: name,
      photoUrl: resolveBloomAssetUrl(entry['target_img_path']),
      lastMessage: (entry['body'] as String?) ?? '',
      lastMessageAt: (entry['print_send_date'] as String?) ?? '',
      unreadCount: asBloomInt(entry['unread_mail_count'] ?? 0),
    );
  }
}
