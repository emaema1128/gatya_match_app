/// `spinGacha`の`status`を表す。`idle`はAPIには存在しない、
/// 「まだ一度も回していない」クライアント専用の初期値。
///
/// `recycled`はgacha-redesignで廃止(旧: レスポンス全体で1つだけ持てた
/// 「今回のカプセルは再表示枠だった」フラグ)——3人排出になり、再表示枠か
/// どうかは[MatchData.isRecycled]としてカプセルごとに持つようになった。
enum GachaSpinStatus { idle, revealed, empty, insufficientPoints, error }

GachaSpinStatus gachaSpinStatusFromApi(String value) => switch (value) {
      'revealed' => GachaSpinStatus.revealed,
      'empty' => GachaSpinStatus.empty,
      'insufficient_points' => GachaSpinStatus.insufficientPoints,
      _ => GachaSpinStatus.error,
    };
