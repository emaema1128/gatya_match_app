<?php 
require_once('../../config/config.php');
require_once($basedir.'Class_DBConnect.php');
require_once($basedir.'Class_Common.php');
require_once($basedir.'Class_User.php');
require_once($basedir.'Class_Campaign.php');
require_once($basedir.'Class_File.php');
require_once($basedir.'Class_News.php');
require_once($basedir.'Class_Contact.php');
require_once($basedir.'Class_Deposit.php');
require_once($basedir.'Class_Board.php');
require_once($basedir.'Class_Likes.php');
require_once($basedir.'Class_Matches.php');
require_once($basedir.'app/api/Class_ProfileApi.php');
require_once($basedir.'app/api/Class_UserApi.php');
require_once($basedir.'app/api/Class_MailApi.php');


$json_post_data = file_get_contents('php://input');
$post_data = json_decode($json_post_data, true);

if (empty($post_data['system_id'])) {
  $return_data = json_encode(['result' => '2', 'error_detail' => 'system_id is null']);
  echo $return_data;
  exit;
}
$system_id = $post_data['system_id'];

$return_data = null;

$headers = getallheaders();
// system_idが-1の場合は、access_tokenのチェックを行わない -1は登録前の通信
if (!User::access_token_verification($headers, $system_id) && (int)$system_id !== -1) {
  $return_data = json_encode(['result' => '2', 'error_detail' => 'Access token is invalid']);
  echo $return_data;
  exit;
}

switch ($post_data['execute_function']) {
  case 'getAreaList':
    $area = ProfileApi::getAreaList();
    $return_data = json_encode(['result' => '1', 'data' => ['area_list' => $area]]);
    break;
  case 'getAgeList':
    $age_list = ProfileApi::getAgeList();
    $return_data = json_encode(['result' => '1', 'data' => ['age_list' => $age_list]]);
    break;
  case 'getIncomeList':
    $income_list = ProfileApi::getIncomeList();
    $return_data = json_encode(['result' => '1', 'data' => ['income_list' => $income_list]]);
    break;
  case 'getAddressList':
    $address_list = ProfileApi::getAddressList();
    $return_data = json_encode(['result' => '1', 'data' => ['address_list' => $address_list]]);
    break;

  // -----------------------ユーザー関連------------------------
  case 'getUserData':
    $user_data = User::getUserData($system_id, 'str');
    $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $user_data]]);
    break;
  case 'registUser':
    $user_data = UserApi::registUser($post_data);
    $system_id = $user_data['system_id'];
    $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $user_data]]);
    break;
  case 'getUserList':
    $user_list = UserApi::getUserList($post_data);
    foreach ($user_list as &$user) {
      $user['PR'] = FreeArea::sptEncode($user['PR'], $post_data['system_id'], $user['system_id']);
    }
    $return_data = json_encode(['result' => '1', 'data' => ['user_list' => $user_list]]);
    break;

  // -----------------------検索関連------------------------
  case 'search':
    $search_result = UserApi::searchUser($post_data);
    foreach ($search_result as &$result) {
      $result['PR'] = FreeArea::sptEncode($result['PR'], $post_data['system_id'], $result['system_id']);
    }
    $return_data = json_encode(['result' => '1', 'data' => ['search_result' => $search_result]]);
    break;

  // -----------------------プロフィール関連------------------------
  case 'updateProfile':
    $result = ProfileApi::updateProfile($post_data);
    if ($result) {
      $user_data = User::getUserData($system_id, 'str');
      $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $user_data]]);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'profile update failure']);
    }
    break;
  case 'uploadProfileImg':
    $img_path = [];
    for ($i = 1; $i <= 3; $i++) {
      if (!empty($post_data["image_{$i}"])) {
        $img_path_str = File::saveBase64Image($post_data["image_{$i}"], $system_id, $basedir, 'profile_img');
        $img_path[$i] = ltrim($img_path_str, '/');
      }
    }
    if (ProfileApi::uploadProfileImg($system_id, $img_path, $basedir)) {
      $user_data = User::getUserData($system_id, 'str');
      $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $user_data]]);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'image upload failure']);
    }
    break;
  case 'deleteProfileImg':
    if (ProfileApi::deleteProfileImg($system_id, $post_data['img_id'], $basedir)) {
      $user_data = User::getUserData($system_id, 'str');
      $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $user_data]]);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'image delete failure']);
    }
    break;

  // -----------------------お気に入り関連------------------------
  case 'getFavoriteList':
    $favorite_charas = User::getFavoriteCharasData($system_id);
    $favorite_charas = !empty($favorite_charas) ? $favorite_charas : null;
    $return_data = json_encode(['result' => '1', 'data' => ['favorite_list' => $favorite_charas]]);
    break;
  case 'updateFavorite':
    if (UserApi::updateFavorite($post_data)) {
      $user_data = User::getUserData($system_id, 'str');
      $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $user_data]]);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'favorite update failure']);
    }
    break;

  // -----------------------ブロック関連------------------------
  case 'updateContactNg':
    if (UserApi::updateContactNg($post_data)) {
      $user_data = User::getUserData($system_id, 'str');
      $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $user_data]]);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'contact_ng update failure']);
    }
    break;

  // -----------------------退会関連------------------------
  case 'withdrawn':
    User::setMemberStatus($system_id, User::MEMBER_STATUS_WITHDRAWN);
    $return_data = json_encode(['result' => '1', 'data' => ['status' => 'success']]);
    break;

  // -----------------------メール（メッセージ）関連------------------------
  case 'getMailList':
    $mail_list = MailApi::getMailList($system_id);
    $return_data = json_encode(['result' => '1', 'data' => ['mail_list' => $mail_list]]);
    break;
  case 'getCommunicateMailList':
    $mail_list = MailApi::getCommunicateMailList($system_id);
    $return_data = json_encode(['result' => '1', 'data' => ['communicate_mail_list' => $mail_list]]);
    break;
  case 'getMailListForMatching':
    $mail_list = MailApi::getMailListForMatching($system_id);
    $return_data = json_encode(['result' => '1', 'data' => ['mail_list' => $mail_list]]);
    break;
  case 'getMailLog':
    $return_data = MailApi::getMailLogAsc($system_id, $post_data['target_id']);
    if (empty($return_data)) {
      $return_data = [];
    }
    $return_data = json_encode(['result' => '1', 'data' => ['mail_log' => $return_data]]);
    break;
  case 'sendMail':
    if (!MailApi::checkBalance($system_id, $post_data['to_id'], PayCost::SEND_MAIL)) {
      $return_data = json_encode(['result' => '1', 'data' => ['error_detail' => 'Insufficient points'] ]);
      echo $return_data;
      exit;
    }
    $result = MailApi::sendMail($system_id, $post_data['to_id'], $post_data['body'], $post_data['reply_to'] ?? null);
    if ($result) {
      $mail_log = MailApi::getMailLogAsc($system_id, $post_data['to_id']);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Mail sending failed']);
      echo $return_data;
      exit;
    }
    $user_data = User::getUserData($system_id, 'str');
    $return_data = json_encode(['result' => '1', 'data' => ['mail_log' => $mail_log, 'user_data' => $user_data]]);
    break;
  case 'sendImgMail':
    $img_path = null;
    if (!empty($post_data['image'])) {
      $img_path = File::saveBase64Image($post_data['image'], $system_id, $basedir, 'message_img');
    }
    if ($img_path) {
      $body = '画像送信';
      if (!MailApi::checkBalance($system_id, $post_data['to_id'], PayCost::SEND_PHOTO)) {
        $return_data = json_encode(['result' => '1', 'data' => ['error_detail' => 'Insufficient points'] ]);
        echo $return_data;
        exit;
      }
      $result = MailApi::sendMail($system_id, $post_data['to_id'], $body, $post_data['reply_to'] ?? null, $img_path);
      if ($result) {
        $mail_log = MailApi::getMailLogAsc($system_id, $post_data['to_id']);
        $user_data = User::getUserData($system_id, 'str');
        $return_data = json_encode(['result' => '1', 'data' => ['mail_log' => $mail_log, 'user_data' => $user_data]]);
      } else {
        $return_data = json_encode(['result' => '2', 'error_detail' => 'Mail sending failed']);
      }
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Image upload failed']);
      echo $return_data;
      exit;
    }
    break;
  case 'lookImgMail':
    if (!Mail::existImageDisplayLog($system_id, $post_data['mail_id'])) {
      if (!MailApi::checkBalance($system_id, $post_data['target_id'], PayCost::MAIL_PHOTO)) {
        $return_data = json_encode(['result' => '1', 'data' => ['error_detail' => 'Insufficient points'] ]);
        echo $return_data;
        exit;
      }
      if(!Point::usePoint($system_id,$post_data['target_id'],PayCost::MAIL_PHOTO)){
        $return_data = json_encode(['result' => '2', 'error_detail' => 'Failed to use points']);
        echo $return_data;
        exit;
      }
    }
    Mail::insertImageDisplayLog($system_id, $post_data['mail_id']);
    $user_data = User::getUserData($system_id, 'str');
    $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $user_data]]);
    break;
  case 'setReadFlag':
    if (MailApi::setReadFlag($system_id, $post_data['target_id'])) {
      $return_data = json_encode(['result' => '1']);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Failed to set read flag']);
    }
    break;
  case 'setAllReadFlagMail':
    if (MailApi::setAllReadFlag($system_id)) {
      $return_data = json_encode(['result' => '1']);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Failed to set all read flag']);
    }
    break;
  case 'sendAudioMail':
    $audio_path = null;
    if (!empty($post_data['audio'])) {
      $audio_ext = $post_data['audio_ext'] ?? 'wav';
      $audio_path = File::saveBase64Audio($post_data['audio'], $system_id, $basedir, 'message_audio', $audio_ext);
    }
    if ($audio_path) {
      $body = '音声送信';
      if (!MailApi::checkBalance($system_id, $post_data['to_id'], PayCost::SEND_AUDIO)) {
        $return_data = json_encode(['result' => '1', 'data' => ['error_detail' => 'Insufficient points'] ]);
        echo $return_data;
        exit;
      }
      $result = MailApi::sendMail($system_id, $post_data['to_id'], $body, $post_data['reply_to'] ?? null, null, $audio_path);
      if ($result) {
        $mail_log = MailApi::getMailLogAsc($system_id, $post_data['to_id']);
        $user_data = User::getUserData($system_id, 'str');
        $return_data = json_encode(['result' => '1', 'data' => ['mail_log' => $mail_log, 'user_data' => $user_data]]);
      } else {
        $return_data = json_encode(['result' => '2', 'error_detail' => 'Mail sending failed']);
      }
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Audio upload failed']);
      echo $return_data;
      exit;
    }
    break;
  case 'playAudioMail':
    if (!Mail::existAudioPlayLog($system_id, $post_data['mail_id'])) {
      if (!MailApi::checkBalance($system_id, $post_data['target_id'], PayCost::PLAY_AUDIO)) {
        $return_data = json_encode(['result' => '1', 'data' => ['error_detail' => 'Insufficient points'] ]);
        echo $return_data;
        exit;
      }
      if(!Point::usePoint($system_id,$post_data['target_id'],PayCost::PLAY_AUDIO)){
        $return_data = json_encode(['result' => '2', 'error_detail' => 'Failed to use points']);
        echo $return_data;
        exit;
      }
    }
    Mail::insertAudioPlayLog($system_id, $post_data['mail_id']);
    $user_data = User::getUserData($system_id, 'str');
    $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $user_data]]);
    break;

  // -----------------------お知らせ関連------------------------
  case 'getNewsList':
    $news_list = News::getNewsList($system_id);
    if (empty($news_list)) {
      $news_list = [];
    }
    $return_data = json_encode(['result' => '1', 'data' => ['news_list' => $news_list]]);
    break;
  case 'getNews':
    $news_item = News::getData($post_data['news_id']);
    if (empty($news_item)) {
      $news_item = [];
    }
    News::setOpenDate($post_data['news_id']);
    $return_data = json_encode(['result' => '1', 'data' => ['news' => $news_item]]);
    break;
  case 'setAllReadFlagNews':
    if (News::setAllReadFlag($system_id)) {
      $return_data = json_encode(['result' => '1']);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Failed to set all read flag']);
    }
    break;

  // -----------------------お問い合わせ関連------------------------
  case 'getContactList':
    $contact_list = Contact::getContactList($system_id);
    $return_data = json_encode(['result' => '1', 'data' => ['contact_list' => $contact_list]]);
    break;
  case 'sendContact':
    $img_path = null;
    if ($post_data['image']) {
      $img_path = File::saveBase64Image($post_data['image'], $system_id, $basedir, 'contact_img');
    }
    $title = $post_data['title'] ?? '';
    $body = $post_data['body'] ?? '';
    $result = Contact::sendContact($system_id, $title, $body, $img_path);
    if ($result) {
      $contact_list = Contact::getContactList($system_id);
      $return_data = json_encode(['result' => '1', 'data' => ['contact_list' => $contact_list]]);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Contact sending failed']);
    }
    break;

  // -----------------------ポイント関連------------------------
  case 'getPriceList':
    $user_data = User::getUserData($system_id, 'str');
    $is_postpaid = Deposit::isPostpaid($system_id);
    $payment_method_key = 'in_app_purchase';// アプリ内課金のためDBの値と合わせる。configに記載はなしでいいと思う
    $payment_method = Deposit::getPaymentMethodFromKey($payment_method_key);
    $bank_deposit_price_list = Deposit::getPrices($user_data['add_point_group_id'], $payment_method['payment_method_id'], 0);
    if (empty($bank_deposit_price_list)) {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Price list is empty']);
      echo $return_data;
      exit;
    }
    $return_data = json_encode(['result' => '1', 'data' => ['price_list' => $bank_deposit_price_list, 'user_data' => $user_data]]);
    break;
  case 'addPoint':
    if (empty($post_data['deposit_amount'])) {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'deposit amount is empty']);
      echo $return_data;
      exit;
    }
    $deposit_amount = $post_data['deposit_amount'];

    $payment_method_key = 'in_app_purchase';// アプリ内課金のためDBの値と合わせる。configに記載はなしでいいと思う
    // payment_method_keyからpayment_method_idを取得
    $payment_method = Deposit::getPaymentMethodFromKey($payment_method_key);
    $result = Deposit::addBalance($system_id, $payment_method['payment_method_id'], $deposit_amount, null, null, null, null, $post_data['order_id'] ?? null, $post_data['purchase_token'] ?? null);
    if ($result) {
      $user_data = User::getUserData($system_id, 'str');
      $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $user_data, 'duplicate' => false]]);
    } else {
      $exist_deposit = Deposit::checkDuplicateDeposit($post_data['order_id'] ?? null, $post_data['purchase_token'] ?? null);
      if ($exist_deposit) {
        $return_data = json_encode(['result' => '1', 'data' => ['user_data' => User::getUserData($system_id, 'str'), 'duplicate' => true]]);
      } else {
        $return_data = json_encode(['result' => '2', 'error_detail' => 'Point addition failed']);
      }
    }
    break;
  case 'getPayCostData':
    $user_data = User::getUserData($system_id);
    $pay_cost_data = PayCost::getPayCategoryCostAll($user_data['pay_cost_id']);
    if (!empty($pay_cost_data)) {
      $return_data = json_encode(['result' => '1', 'data' => ['pay_cost_data' => $pay_cost_data]]);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Pay cost data is empty']);
    }
    break;

  // -----------------------掲示板関連------------------------
  case 'getBoardData':
    $open_board_list = Board::getOpenBoardList();
    $first_board_id = !empty($open_board_list) ? reset($open_board_list)['board_id'] : null;
    if (empty($first_board_id)) {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'No open boards available']);
      echo $return_data;
      exit;
    }
    $board_data = Board::getPostedMessagesData($first_board_id, $system_id);
    foreach ($board_data as &$message) {
      $message['PR'] = FreeArea::sptEncode($message['PR'], $system_id, $message['system_id']);
    }
    $return_data = json_encode(['result' => '1', 'data' => ['board_data' => $board_data]]);
    break;
  
  case 'writeBoardMessage':
    if (empty($post_data['board_id']) || empty($post_data['body'])) {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'board_id or body is empty']);
      echo $return_data;
      exit;
    }
    $subject = '';
    if (Board::writeMessage($post_data['board_id'], $system_id, $subject, $post_data['body'])) {
      $return_data = json_encode(['result' => '1', 'data' => 'success']);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Message posting failed']);
    }
    break;
    
  // -----------------------共通処理関連------------------------
  case 'login':
    $login_result = UserApi::login($post_data['login_id'], $post_data['password'], $post_data['fcm_device_token']);
    if ($login_result) {
      $user_data = User::getUserData($login_result['system_id'], 'str');
      $system_id = $user_data['system_id'];
      $return_data = json_encode(['result' => '1', 'data' => ['user_data' => $user_data]]);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Invalid login credentials']);
    }
    break;
  case 'existsDeviceId':
    $adjust_device_id = $post_data['adjust_id'] ?? null;
    if (UserApi::existsDeviceId($post_data['device_id']) || UserApi::existsAdjustId($adjust_device_id)) {
      $return_data = json_encode(['result' => '1', 'data' => ['status' => 'exists']]);
    } else {
      $return_data = json_encode(['result' => '1', 'data' => ['status' => 'not_exists']]);
    }
    break;
  case 'verificationAfterLoginProcess':
    Common::verificationAfterLoginProcess($system_id);
    if (!empty($post_data['app_version'])) {
      UserApi::updateAppVersion($system_id, $post_data['app_version']);
    }
    if (!empty($post_data['app_build_number'])) {
      UserApi::updateAppBuildNumber($system_id, $post_data['app_build_number']);
    }
    $return_data = json_encode(['result' => '1']);
    break;
  case 'unreadCount':
    $unread_data['unread_mail_count'] = Mail::unreadMailCount($system_id);
    $unread_data['unread_news_count'] = News::unreadNewsCount($system_id);
    $return_data = json_encode(['result' => '1', 'data' => ['unread_data' => $unread_data]]);
    break;
  case 'getAppLatestVersion':
    $android_latest_version = Common::getGeneralConfig('android_latest_version');
    $return_data = json_encode(['result' => '1', 'data' => ['android_latest_version' => $android_latest_version]]);
    break;
  case 'saveBillingLogs':
    if (empty($post_data['reason']) || ((int)$post_data['is_success'] !== 1 && (int)$post_data['is_success'] !== 0) || empty($post_data['logs']) || !is_array($post_data['logs'])) {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Invalid billing log data']);
      echo $return_data;
      exit;
    }
    $reason = $post_data['reason'];
    $is_success = (int)$post_data['is_success'];
    $logs_arr = $post_data['logs'];
    $logs_json = json_encode($logs_arr);
    if (Deposit::saveAppBillingLogs($system_id, $reason, $is_success, $logs_json)) {
      $return_data = json_encode(['result' => '1', 'data' => ['status' => 'success']]);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Failed to save billing logs']);
    }
    break;
  // -----------------------キャンペーン関連------------------------
  case 'getCampaignList':
    $campaign_list = Campaign::getCampaignsRegistBaseTrigger($system_id);
    $return_data = json_encode(['result' => '1', 'data' => ['campaign_list' => $campaign_list]]);
    break;
  // -----------------------いいね、マッチング関連------------------------
  case 'sendLike':
    if (empty($post_data['target_id'])) {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Target user ID is empty']);
      echo $return_data;
      exit;
    }
    $target_id = $post_data['target_id'];
    $like_type = Likes::LIKE_TYPE_NORMAL;

    $to_me_like = Likes::existsLike($target_id, $system_id); // 相手からのいいねが存在するか
    $my_like = Likes::existsLike($system_id, $target_id); // 自分からのいいねが存在するか
    if (!empty($to_me_like)) {
      // 相手からのいいねが存在する場合はマッチング
      Likes::updateLikeStatus($to_me_like['like_id'], Likes::STATUS_MATCH);
      Likes::updateMatchDate($to_me_like['like_id']);
      Matches::matching($system_id, $target_id, $to_me_like['like_id']);
      Automation::checkTriggerMatches($target_id, $system_id);
      $send_or_match_system_ids = Likes::getSendOrMatchSystemIds($system_id);
      $return_data = json_encode(['result' => '1', 'data' => ['send_or_match_system_ids' => $send_or_match_system_ids, 'status' => 'match']]);
    } else if (!empty($my_like)) {
      // 自分からのいいねが存在する場合は何もしない
      $return_data = json_encode(['result' => '1']);
    } else {
      // いいねを送信
      $result = Likes::sendLike($system_id, $target_id, $like_type);
      if ($result) {
        $send_or_match_system_ids = Likes::getSendOrMatchSystemIds($system_id);
        $send_like_list = Likes::getSendLikeList($system_id);
        $return_data = json_encode(['result' => '1', 'data' => ['send_or_match_system_ids' => $send_or_match_system_ids, 'send_like_list' => $send_like_list, 'status' => 'send']]);
      } else {
        $return_data = json_encode(['result' => '2', 'error_detail' => 'Likes sending failed']);
        echo $return_data;
        exit;
      }
    }
    break;
  case 'sendMatchingMail':
    if (empty($post_data['target_id']) || empty($post_data['body'])) {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Target user ID or mail body is empty']);
      echo $return_data;
      exit;
    }
    $target_id = $post_data['target_id'];
    if (!MailApi::checkBalance($system_id, $target_id, PayCost::SEND_MATCHING_MAIL)) {
      $return_data = json_encode(['result' => '1', 'data' => ['error_detail' => 'Insufficient points'] ]);
      echo $return_data;
      exit;
    }
    if (!empty(User::getRejectMatchingMailFlag($target_id))) {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'The user does not accept matching mails']);
      echo $return_data;
      exit;
    }

    $to_me_like = Likes::existsLike($target_id, $system_id); // 相手からのいいねが存在するか
    $my_like = Likes::existsLike($system_id, $target_id); // 自分からのいいねが存在するか

    if (!empty($to_me_like)) {
      // 相手からのいいねが存在する場合はマッチング
      Likes::updateLikeStatus($to_me_like['like_id'], Likes::STATUS_MATCH);
      Likes::updateMatchDate($to_me_like['like_id']);
      Matches::matching($system_id, $target_id, $to_me_like['like_id']);
      // Automation::checkTriggerMatches($target_id, $system_id);
      $send_or_match_system_ids = Likes::getSendOrMatchSystemIds($system_id);
      $return_data = json_encode(['result' => '1', 'data' => ['send_or_match_system_ids' => $send_or_match_system_ids, 'status' => 'match']]);
    } else if (!empty($my_like)) {
      // 自分からのいいねが存在する場合は何もしない
      $return_data = json_encode(['result' => '1']);
    } else {
      // マッチングメールの送信
      $like_type = Likes::LIKE_TYPE_MATCHING_MAIL;
      $result = Likes::sendLike($system_id, $target_id, $like_type);
      if ($result) {
        $like_id = Likes::getLikeId($system_id, $target_id);
        Likes::updateLikeStatus($like_id, Likes::STATUS_MATCH);
        Likes::updateMatchDate($like_id);
        Matches::matching($system_id, $target_id, $like_id);
        $matching_mail_flag = true;
        $send_result = MailApi::sendMail($system_id, $target_id, $post_data['body'], null, null, null, $matching_mail_flag);
        if ($send_result) {
          Automation::checkTriggerMatches($target_id, $system_id);
          $send_or_match_system_ids = Likes::getSendOrMatchSystemIds($system_id);
          $return_data = json_encode(['result' => '1', 'data' => ['send_or_match_system_ids' => $send_or_match_system_ids, 'status' => 'match']]);
        } else {
          $return_data = json_encode(['result' => '2', 'error_detail' => 'Matching mail sending failed']);
          echo $return_data;
          exit;
        }
      }
    }

    break;
  case 'getSendLikeList':
    $send_like_list = Likes::getSendLikeList($system_id);
    foreach ($send_like_list as &$send_like) {
      $send_like['PR'] = FreeArea::sptEncode($send_like['PR'], $post_data['system_id'], $send_like['system_id']);
    }
    $return_data = json_encode(['result' => '1', 'data' => ['send_like_list' => $send_like_list]]);
    break;
  case 'getLikeData':
    $like_data = Likes::getLikeData($post_data['target_id'], $system_id);
    if (empty($like_data)) {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Like data is empty']);
      echo $return_data;
      exit;
    }
    $return_data = json_encode(['result' => '1', 'data' => ['like_data' => $like_data]]);
    break;
  case 'getReceivedLikeList':
    $received_like_list = Likes::getReceivedLikeList($system_id);
    $return_data = json_encode(['result' => '1', 'data' => ['received_like_list' => $received_like_list]]);
    break;
  case 'getSendOrMatchSystemIds':
    $send_or_match_system_ids = Likes::getSendOrMatchSystemIds($system_id);
    $return_data = json_encode(['result' => '1', 'data' => ['send_or_match_system_ids' => $send_or_match_system_ids]]);
    break;
  case 'getMatchList':
    $match_list = Matches::getMatchList($system_id);
    foreach ($match_list as &$match) {
      $match['PR'] = FreeArea::sptEncode($match['PR'], $post_data['system_id'], $match['system_id']);
    }
    $return_data = json_encode(['result' => '1', 'data' => ['match_list' => $match_list]]);
    break;

  // -----------------------申請関連------------------------
  case 'getUserRequestData':
    if (empty($post_data['target_id'])) {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Target ID is empty']);
      echo $return_data;
      exit;
    }
    $target_id = $post_data['target_id'];
    // 自分が相手に送った申請データを取得
    $user_request = User::getUserRequest($system_id, $target_id);
    $pay_cost_data = PayCost::getPayCategoryCost($system_id,PayCost::USER_REQUEST, $target_id);
    $return_data = json_encode(['result' => '1', 'data' => ['user_request' => $user_request, 'user_request_pay_cost' => $pay_cost_data]]);
    break;
  case 'getReceiveRequestData':
    if (empty($post_data['target_id'])) {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Target ID is empty']);
      echo $return_data;
      exit;
    }
    $target_id = $post_data['target_id'];
    // 相手が自分に送った申請データを取得
    $user_request = User::getUserRequest($target_id, $system_id);
    $return_data = json_encode(['result' => '1', 'data' => ['user_request' => $user_request]]);
    break;
  case 'userRequest':
    if (empty($post_data['target_id'])) {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Target ID is empty']);
      echo $return_data;
      exit;
    }
    $target_id = $post_data['target_id'];
    if (!MailApi::checkBalance($system_id, $target_id, PayCost::USER_REQUEST)) {
      $return_data = json_encode(['result' => '1', 'data' => ['error_detail' => 'Insufficient points'] ]);
      echo $return_data;
      exit;
    }
    $result = UserApi::userRequest($system_id, $target_id);
    if ($result) {
      $user_request = User::getUserRequest($system_id, $target_id);
      $user_data = User::getUserData($system_id, 'str');
      $return_data = json_encode(['result' => '1', 'data' => ['user_request' => $user_request, 'user_data' => $user_data]]);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Request submission failed']);
    }
    break;
  case 'updateUserRequest':
    if (empty($post_data['target_id']) || !isset($post_data['new_status']) || !isset($post_data['request_id'])) {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Target ID, request ID or new status is empty']);
      echo $return_data;
      exit;
    }
    $target_id = $post_data['target_id'];
    $request_id = $post_data['request_id'];
    $new_status = (int)$post_data['new_status'];
    $result = UserApi::updateUserRequestStatus($request_id, $new_status);
    if ($result) {
      $user_request = User::getUserRequest($target_id, $system_id);
      $user_data = User::getUserData($system_id, 'str');
      $return_data = json_encode(['result' => '1', 'data' => ['user_request' => $user_request, 'user_data' => $user_data]]);
    } else {
      $return_data = json_encode(['result' => '2', 'error_detail' => 'Failed to update request status']);
    }
    break;
  // -----------------------default------------------------
  default:
    $return_data = json_encode(['result' => '2', 'error_detail' => 'Invalid function name']);
    break;
}

if (!empty($system_id) && (int)$system_id !== -1) {
  User::updateSessionDate($system_id); // 最終セッション日の更新
}

echo $return_data;
?>