Type: task
Status: resolved

## Question

Profile作成/編集画面の設計前に、bloomバックエンドのProfile関連APIの未確認仕様を洗い出す。`route_api.php`(ディスパッチ層)から読み取れるのは関数名とトップレベルの引数/戻り値キー名のみで、実装クラス(`Class_ProfileApi.php`)はこのリポジトリにもファイルシステム上にも見当たらない(検索済み、不在確認済み)。

確認すべき点:

1. `getAgeList`/`getIncomeList`/`getAddressList`が返すデータの実際の形(`getAreaList`と同じidマップ形式か、階層構造の有無、選択肢の内容・件数)。
2. `getAddressList`が返す「住所」は、登録時に既に集めている地域(region/prefecture/city)とは別物(番地・郵便番号など、より詳細な住所)かどうか(`/wayfinder`のQ6でユーザーは「たぶん別物」と回答、未確証)。
3. `updateProfile`が要求する必須/任意パラメータ(ディスパッチャは`$post_data`をそのまま`ProfileApi::updateProfile($post_data)`へ渡しており、キー名を列挙できない)。フィールドごとの逐次呼び出しを想定した設計か、フォーム全体の一括送信を想定した設計かも含む。
4. `uploadProfileImg`(`image_1`/`image_2`/`image_3`、base64、最大3枚)/`deleteProfileImg`(`img_id`)の詳細——`img_id`はどこから取得するか(`user_data`内に含まれる写真情報の形)。

バックエンドソースにアクセスできるユーザー自身が確認するか、実際に認証済みアカウントでテスト呼び出しを行い報告する形で解決する(Stage1の[01-bloom-api-spec-confirmation](../../stage1-auth-screens/issues/01-bloom-api-spec-confirmation.md)と同じ進め方)。

## Answer

ユーザーが実ソース(`Class_ProfileApi.php`/`Class_Profile.php`/`Class_UserApi.php`、`document/blooom関係/dream`配下)を共有してくれたことで確認済み。

1. **`getAgeList`/`getIncomeList`/`getAddressList`の形**: 3つとも`getAreaList`のような階層構造(lv1/2/3)ではなく、**フラットな選択肢マップ**。`ProfileApi::getAgeList()`(引数なし)は`Profile::getAgeListAll()`を呼び、`profile_age`テーブルの全行(性別問わず)を`age_id`をキーとしたマップで返す。各行は`{age_id, age_item, sex}`という構造(`age_item`が表示ラベルの文字列、`sex`は行ごとに付随する性別)。`income`/`address`も同様に`profile_income`/`profile_address`テーブルから同じ形で返る。件数・具体的な選択肢文言はDB内容次第で未確認。
2. **address(住所)とarea(地域)の関係**: **別物と判明**したが、想定していた「番地までの詳細住所」ではなかった。`profile_address`は`profile_age`/`profile_income`と同型の**カテゴリカルな選択肢テーブル**(id→ラベル文字列)で、番地・郵便番号のような自由記述の住所ではない。デフォルト表示名は「お住まい」(`getAddressViewName()`のフォールバック)。既に登録時に集めている地域(`region`/`prefecture`/`city`、`getAreaList`由来)とは完全に別のテーブル・別の概念で、両方とも`user`テーブルの別カラム(`area1_id`/`area2_id`/`area3_id` vs `address_id`)。
3. **`updateProfile`のパラメータ**: `system_id`のみ必須(空だと`false`を返す)。それ以外は`username`/`age_id`/`income_id`/`address_id`/`PR`/`reject_matching_mail_flag`をそれぞれ`$post_data[...] ?? $user_data[...]`(null合体)で読み取る——**送らなかった項目は既存値がそのまま維持される部分更新設計**。フィールドごとに個別呼び出しする必要はなく、変更したいものだけをまとめて1回で送れる。
   - **新たな発見**: `updateProfile`は当初想定していなかった`username`(ニックネーム、`registUser`時のデフォルトは`'ゲスト'`)と`reject_matching_mail_flag`(マッチングメール拒否設定)も扱う。`PR`(自己紹介、Account作成時に収集済み)もここで再編集可能。
4. **写真系API詳細**: `uploadProfileImg($system_id, $img_path, $basedir)`は`image_1`〜`image_3`のうち存在するものだけ処理し、`File::createCompressImage`で圧縮版も生成、`user`テーブルの`img{N}_path`/`img{N}_compress_path`/`img{N}_check`を更新。アップロード前に古い画像ファイルがあれば自動削除(置き換え)。`deleteProfileImg`の`img_id`は**1/2/3のスロット番号**(`img{$img_id}_path`のようにカラム名へ直接埋め込まれる)——`user_data`に含まれる`img1_path`/`img2_path`/`img3_path`(および圧縮版)がその実体で、そこから対象を選ぶ。

この結果を踏まえ、[03-profile-screen](03-profile-screen.md)のスコープに`username`(ニックネーム)と`reject_matching_mail_flag`(マッチングメール拒否設定)を追加した。
