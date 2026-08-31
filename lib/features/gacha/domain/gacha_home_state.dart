import '../../matches/domain/match_data.dart';
import 'gacha_spin_status.dart';

class GachaHomeState {
  const GachaHomeState({required this.balance, required this.status, required this.candidates});

  /// 保有ポイント残高。
  final int balance;

  /// ガチャ抽選結果の状態(idle/revealed/empty/insufficientPoints/error)。
  final GachaSpinStatus status;

  /// 排出されたお相手候補(`status == revealed`の時のみ非空)。
  final List<MatchData> candidates;
}
