Type: grilling
Status: resolved

## Question

マップのDestinationは「ガチャ結果カード・**一覧**のカードをタップすると、そのお相手のプロフィールを閲覧できる」ことを求めているが、[issue06](06-like-match-tab-implementation.md)の実装時点で、いいね/マッチタブ(`MatchListScreen`)が使う共通カード`MatchProfileCard`にはタップハンドラが一切なく、一覧側からのプロフィール閲覧導線が未実装であることが判明した。

ガチャ排出画面側は[issue05](05-gacha-home-screen-revamp-implementation.md)で「タップで`showModalBottomSheet`(`DraggableScrollableSheet`)により写真ギャラリー+年齢/居住地/年収+自己紹介全文を表示」という方式を採用済み。

含めるべき論点:

1. いいね/マッチ一覧のカードタップも同じボトムシート方式を流用するか、それとも独立した新規ルート(画面)にするか(一覧からの遷移は「戻る」導線が自然に欲しくなる可能性があり、ガチャ排出画面のような「その場に留まる」演出とはユースケースが異なるかもしれない)。
2. 表示できるデータは[issue03](03-other-profile-view-data-research.md)の調査通りバックエンド変更なしで足りる(`income_id`/`img2`/`img3`含む)ため、データ面の追加調査は不要。
3. ボトムシート方式・独立画面方式のどちらでも、`MatchProfileCard`を使っている画面すべて([match_celebration_screen.dart](../../../../lib/features/matches/presentation/match_celebration_screen.dart)含む)への影響を確認する。

## Answer

1. **ボトムシート方式を採用**(独立した新規ルートは追加しない)。ガチャ排出画面(issue05)で実装済みの`_ProfileDetailsSheet`を`ProfileDetailsSheet`として`lib/features/matches/presentation/profile_details_sheet.dart`に切り出し、`showProfileDetailsSheet(context, match)`ヘルパーとともに共通化。`GachaRevealScreen`側もこの共通ウィジェットを呼ぶように変更済み(見た目・挙動は変わらない)。
2. データ面はissue03の調査通り追加調査不要、変更なし。
3. `MatchProfileCard`(いいねタブ・マッチタブ・[match_celebration_screen.dart](../../../../lib/features/matches/presentation/match_celebration_screen.dart)の3箇所すべてで共用)に`InkWell`でタップ検知を追加し、タップで`showProfileDetailsSheet`を呼ぶよう変更。個別の画面側の変更は不要で、3箇所すべてに自動的に反映される。ユーザーの直接確認により、3箇所とも同じ挙動(タップ可能)にすることを決定——画面によってタップの有効/無効を出し分ける実装は行っていない。
4. 課金は行わない(無料のまま)。map.mdの「Not yet specified」にあった未決事項もこれで解消。

新規ルート・新規プロバイダー・バックエンド変更なし。`dart analyze lib`はクリーン(既存の無関係な指摘のみ)。
