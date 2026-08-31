import 'chat_message.dart';

/// 個別チャットスレッド画面の表示状態。
class ChatThreadState {
  const ChatThreadState({required this.balance, required this.messages});

  final int balance;
  final List<ChatMessage> messages;
}
