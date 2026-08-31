Type: grilling
Status: resolved

## Question

マッチした相手とのチャットを、bloom既存の「1通ごとに課金」モデル(`Mail::sendMail`が例外なく`Point::usePointMail`を呼ぶ)のまま実装するか、それともマッチ済みなら無料でメッセージし放題にするかを決定する。後者を選ぶ場合はバックエンド変更(`Mail::sendMail`の条件分岐追加等)が必要になる。

## Answer

**既存の課金モデルをそのまま継承する。** マッチ相手とのやり取りも無料にはしない。

理由: bloomの既存ビジネスモデル(1通ごとの課金)と一致させることが優先され、バックエンド変更を最小限に抑えられる(既存の`sendMail`/`sendImgMail`/`sendAudioMail`をそのまま呼ぶだけで済む)。これにより、このマップはバックエンド変更が一切不要になった。
