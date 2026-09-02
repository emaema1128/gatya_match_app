// pi(円周率)とsin/cos(三角関数)を使ってアニメーションの揺れ・弧・放射状の動きを計算する。
import 'dart:math' show pi, sin, cos;

import 'package:flutter/material.dart'; // ボタンやテキストなど基本的なUI部品(マテリアルデザイン)
import 'package:flutter_riverpod/flutter_riverpod.dart'; // 状態管理ライブラリ「Riverpod」
import 'package:video_player/video_player.dart'; // 動画ファイル(mp4等)を再生するためのパッケージ

import '../../../core/network/bloom_api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../../matches/domain/match_data.dart'; // ガチャで出てくる「お相手」1人分のデータ
import '../application/gacha_controller.dart'; // ガチャを回す処理(通信など)を担当する部分
import '../domain/gacha_home_state.dart'; // この画面が今どんな状態か(残高・候補一覧など)を表すデータ
import '../domain/gacha_spin_status.dart'; // ガチャの状態(未実行/結果あり/エラーなど)を表す種類分け

/// ホーム画面(ガチャ)。[gacha-redesign](../../../../.scratch/gacha-redesign/map.md)の決定に基づく:
/// ガチャボタンを中央配置し、タップするとガチャ本体(`assets/images/gacha_machine.png`)からカプセルが排出される。
/// 3人(候補が少ない場合は1〜2人)のカプセルが弧を描いて飛び出し、[GachaRevealRoute](フルスクリーンのスワイプカード画面)へ自動的に遷移する。
// ConsumerStatefulWidget = 「状態(State)を持てる」かつ「Riverpodのref(プロバイダーの値を読む窓口)が使える」ウィジェット。
// ガチャ画面のように表示中に状態が変わる画面はこちらを使う(状態が変わらない画面ならStatelessWidgetでよい)。
class GachaScreen extends ConsumerStatefulWidget {
  const GachaScreen({super.key});

  // このウィジェットの「状態(State)」を作るためのメソッド。
  // Flutterでは「見た目の設計図(Widget)」と「変化する中身(State)」を分けて管理する。
  @override
  ConsumerState<GachaScreen> createState() => _GachaScreenState();
}

// 上のGachaScreenが実際に画面を組み立てる部分。ここに状態(変数)やbuild()メソッド(画面を描く処理)をまとめる。
class _GachaScreenState extends ConsumerState<GachaScreen> {
  // 「ガチャを回す」ボタンが押されたときに呼ばれる処理。
  // ref.read(...).notifier でコントローラー(通信などの実処理担当)を取り出し、spin()メソッドを呼ぶ。
  Future<void> _spin() async {
    await ref.read(gachaControllerProvider.notifier).spin();
  }

  // Flutterの画面は「build」メソッドの中で、今の状態から見た目(Widgetツリー)を組み立てる。状態が変わるとFlutterが自動的にbuildを呼び直して画面を更新する。
  @override
  Widget build(BuildContext context) {
    // ref.watch(...) = このプロバイダー(状態の入れ物)を「監視」する。値が変わるたびに、この画面のbuild()が自動で再実行される。
    // gachaAsyncは「通信中/成功/失敗」をまとめて表すAsyncValueという型。
    final gachaAsync = ref.watch(gachaControllerProvider);

    return Scaffold(
      // Scaffold = 画面の基本の骨組み(上部バー・本体エリアなどを持つ標準的な画面レイアウト)。
      appBar: AppBar(title: const Text('ホーム')),
      body: SafeArea(
        // SafeArea = ノッチ(切り欠き)やステータスバーに文字が重ならないよう余白を作る。
        child: gachaAsync.when(
          // .when(...) はAsyncValueの状態ごとに表示するUIを切り替えるための書き方。
          // data: 通信が成功して値が取れているとき
          // loading: まだ通信中のとき
          // error: 通信などでエラーが起きたとき
          // 通信中は毎回スピナーを表示する(前回の候補を表示したままにしない)。
          skipLoadingOnRefresh: false,
          data: (state) => _buildContent(context, state),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildError(context, error),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, GachaHomeState state) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text('${state.balance} pt', style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(child: Center(child: _buildBody(context, state))),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, GachaHomeState state) {
    // ガチャの状態(status)に応じて表示するUIを切り替える。
    switch (state.status) {
      // ガチャ未実行(idle)のときは、ガチャ本体と「ガチャを回す」ボタンを表示する。
      case GachaSpinStatus.idle:
        return _buildIdle(context);
      // ガチャ実行済み(revealed)のときは、まずドラゴンの動画演出を再生し、
      // 終わったら(動画が無ければ即座に)カプセルが飛び出すいつもの演出に切り替える。
      case GachaSpinStatus.revealed:
        return _GachaSpinRevealAnimation(
        // return _GachaRevealWithDragonIntro( //retrunをこっちに変えると、ドラゴンの動画演出が再生される。
          key: ValueKey(identityHashCode(state)),
          candidates: state.candidates,
          onSpinAgain: _spin,
        );
      // ガチャ実行済みだが候補がいない(empty)のときは、メッセージを表示する。
      case GachaSpinStatus.empty:
        return _buildMessage(context, '今は新しい候補がいません。しばらくしてからまた挑戦してみてください。');
      // ガチャ実行済みだがポイント不足(insufficientPoints)のときは、メッセージを表示する。  
      case GachaSpinStatus.insufficientPoints:
        return _buildMessage(context, 'ポイントが不足しています。ポイントが貯まってからまたお試しください。');
      // ガチャ実行中にエラー(error)が起きたときは、エラーメッセージを表示する。  
      case GachaSpinStatus.error:
        return _buildMessage(context, 'エラーが発生しました。もう一度お試しください。', isError: true);
    }
  }

  Widget _buildIdle(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'ガチャを回すと、お相手が最大3人出てきます。',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _spin,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 32, vertical: 20),
            child: Text('ガチャる', style: TextStyle(fontSize: 18)),
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(BuildContext context, String message, {bool isError = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          message,
          textAlign: TextAlign.center,
          style: isError
              ? TextStyle(color: Theme.of(context).colorScheme.error)
              : Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 16),
        OutlinedButton(onPressed: _spin, child: const Text('もう一度試す')),
      ],
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    final message = error is BloomApiException ? error.errorDetail : '通信状態を確認してください。';
    return Center(child: Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)));
  }
}

List<Offset> _arcTargetsFor(int count) {
  return switch (count) {
    1 => const [Offset(0, 55)],
    2 => const [Offset(-70, 55), Offset(70, 55)],
    _ => const [Offset(-90, 70), Offset(0, 40), Offset(90, 70)],
  };
}

/// 「ガチャる」の直後にドラゴンの動画演出(`assets/videos/gacha_doragon_intro.mp4`、
/// [README](../../../../assets/videos/README.md)参照)をフルスクリーンで再生し、終わったら
/// (または動画素材が無ければ最初から)いつもの[_GachaSpinRevealAnimation](機体+カプセル演出)に
/// 切り替えるラッパー。動画自体は[_DragonIntroFullscreenVideo]をルートとして重ねて表示することで、
/// AppBarやボトムナビも隠した画面いっぱいの演出にしている。
class _GachaRevealWithDragonIntro extends StatefulWidget {
  const _GachaRevealWithDragonIntro({super.key, required this.candidates, required this.onSpinAgain});

  final List<MatchData> candidates;
  final VoidCallback onSpinAgain;

  @override
  State<_GachaRevealWithDragonIntro> createState() => _GachaRevealWithDragonIntroState();
}

class _GachaRevealWithDragonIntroState extends State<_GachaRevealWithDragonIntro> {
  // 動画(フルスクリーンのルート)が閉じたら true にして、いつもの演出に切り替える。
  bool _showCapsuleReveal = false;

  @override
  void initState() {
    super.initState();
    // build()の途中でNavigator.push()すると不具合が起きやすいため、フレーム描画後に開始する。
    WidgetsBinding.instance.addPostFrameCallback((_) => _playDragonIntro());
  }

  Future<void> _playDragonIntro() async {
    if (!mounted) return;
    // rootNavigatorのルートとして重ねることで、ホームタブの外側(AppBar・ボトムナビ)も含めて覆う。
    await Navigator.of(context, rootNavigator: true).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        pageBuilder: (context, animation, secondaryAnimation) => const _DragonIntroFullscreenVideo(),
      ),
    );
    if (mounted) setState(() => _showCapsuleReveal = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_showCapsuleReveal) {
      return _GachaSpinRevealAnimation(candidates: widget.candidates, onSpinAgain: widget.onSpinAgain);
    }
    // フルスクリーンの動画ルートが前面に重なっている間、この場所には何も表示しない。
    return const SizedBox.shrink();
  }
}

/// ドラゴンの動画をデバイス画面いっぱいに再生するフルスクリーンページ。
/// 動画が終わる/スキップされる/素材が見つからない、のいずれかで自身をpopして呼び出し元に戻る。
class _DragonIntroFullscreenVideo extends StatefulWidget {
  const _DragonIntroFullscreenVideo();

  @override
  State<_DragonIntroFullscreenVideo> createState() => _DragonIntroFullscreenVideoState();
}

class _DragonIntroFullscreenVideoState extends State<_DragonIntroFullscreenVideo> {
  static const _videoAssetPath = 'assets/videos/gacha_doragon_intro.mp4';

  VideoPlayerController? _videoController;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(_videoAssetPath);
    try {
      await controller.initialize();
    } catch (_) {
      // 動画ファイルがまだ配置されていない場合など。エラーにせず即座に閉じる。
      controller.dispose();
      _close();
      return;
    }
    if (!mounted) {
      controller.dispose();
      return;
    }
    controller.addListener(_onVideoTick);
    setState(() => _videoController = controller);
    controller.play();
  }

  // 再生位置が動画の長さに達したら、再生終了とみなして閉じる。
  void _onVideoTick() {
    final value = _videoController?.value;
    if (value == null || value.duration == Duration.zero) return;
    if (value.position >= value.duration) _close();
  }

  void _close() {
    if (_closed) return;
    _closed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _videoController?.removeListener(_onVideoTick);
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _videoController;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (controller != null && controller.value.isInitialized)
            // BoxFit.coverと同じ効果を狙って、動画を画面いっぱいに(はみ出す分は切り取って)敷き詰める。
            FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: controller.value.size.width,
                height: controller.value.size.height,
                child: VideoPlayer(controller),
              ),
            ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: TextButton(
                  onPressed: _close,
                  style: TextButton.styleFrom(foregroundColor: Colors.white, backgroundColor: Colors.black45),
                  child: const Text('次へ'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ガチャ本体からカプセルが排出され、震えてバーストし、候補の数だけカプセルが弧を描いて飛び出す演出。
/// 完了すると[GachaRevealRoute]へ自動遷移する(1回だけ、`push`から戻ってきても再遷移しない)。
/// 戻ってきた後は「もう一度ガチャを回す」ボタンに切り替わる(タップで[onSpinAgain]、新しいスピン結果でこのウィジェット自体が新しいキーで再生成される)。
class _GachaSpinRevealAnimation extends StatefulWidget {
  const _GachaSpinRevealAnimation({super.key, required this.candidates, required this.onSpinAgain});

  final List<MatchData> candidates;
  final VoidCallback onSpinAgain;

  @override
  State<_GachaSpinRevealAnimation> createState() => _GachaSpinRevealAnimationState();
}

// SingleTickerProviderStateMixin = アニメーション用の「時計係(Ticker)」を1つ提供できるようにするおまじない。
// AnimationControllerを使うときに必要になる。
class _GachaSpinRevealAnimationState extends State<_GachaSpinRevealAnimation> with SingleTickerProviderStateMixin {
  // AnimationController = 0.0→1.0のように時間とともに値が変化する「進行度」を管理する仕組み。
  // この値(_controller.value)を使って各パーツの動きを計算する。
  late final AnimationController _controller;
  // 候補の人数から計算した、カプセルが飛んでいく着地点のリスト(初期化時に1回だけ作る)。
  late final List<Offset> _arcTargets;
  // GachaRevealRoute(結果表示画面)へすでに遷移したかどうかのフラグ。
  // 二重に遷移してしまうのを防ぐために使う。
  bool _navigatedToReveal = false;

  // タイムライン: 0.00-0.12 本体が押し込まれる(作動) / 0.12-0.25 カプセルが排出口から出てくる / 0.25-1.00 に「震えてバースト」シーケンス
  // (shake/burst/fly/crack)をそのままの比率で圧縮して割り当てる(_oldTで逆算)。
  static const _machinePhaseEnd = 0.25;

  // initState = このウィジェットが画面に最初に現れたときに1回だけ呼ばれる初期化処理。
  @override
  void initState() {
    super.initState();
    _arcTargets = _arcTargetsFor(widget.candidates.length);
    // AnimationControllerを作成し、2300ミリ秒(2.3秒)かけて0→1へ進める設定にする。
    // `..forward()` はカスケード記法(作った直後に続けてメソッドを呼ぶ書き方)で、作成と同時にアニメーションを開始している。
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 2300))..forward();
    // アニメーションの値が変化するたびにsetState()を呼び、画面を再描画(build)させる。
    _controller.addListener(() => setState(() {}));
  }

  // dispose = このウィジェットが画面から消えるときに呼ばれる後片付け処理。
  // AnimationControllerは使い終わったら必ずdispose()してリソースを解放する。
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 現在のアニメーション進行度(0.0〜1.0)を取り出すための短縮用ゲッター。
  // clampで念のため範囲外の値にならないようにしている。
  double get _t => _controller.value.clamp(0.0, 1.0);

  // 全体の進行度tのうち、「本体の演出」が終わった後(_machinePhaseEnd以降)の区間だけを、あらためて0.0〜1.0の進行度として計算し直す(揺れ・バーストなど用)。
  double _oldT(double t) => ((t - _machinePhaseEnd) / (1 - _machinePhaseEnd)).clamp(0.0, 1.0);

  // アニメーションがほぼ完了した(revealed=true)タイミングで、まだ画面遷移していなければ結果画面(GachaRevealRoute)へ1回だけ遷移する。
  void _maybeNavigateToReveal(bool revealed) {
    if (!revealed || _navigatedToReveal) return;
    _navigatedToReveal = true;
    // addPostFrameCallback = 「今描画しているフレームが終わった直後」に処理を実行する。
    // build()の途中で画面遷移すると不具合が起きやすいため、こう書くのが定石。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // mountedチェック = このウィジェットがまだ画面に存在しているかの確認。
      // 遷移前に破棄されていた場合にエラーになるのを防ぐ。
      if (mounted) const GachaRevealRoute().push(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = _t; // 現在の進行度(0.0〜1.0)
    // アニメーションがほぼ最後まで進んだら「もう結果は見せてよい」とみなすためのしきい値判定。
    final revealed = t >= 1 - (1 - _machinePhaseEnd) * 0.03;
    _maybeNavigateToReveal(revealed);

    // アニメーションが完全に終わり、かつ結果画面への遷移も済んでいたら、(結果画面からpushで戻ってきた後を想定して)「もう一度回す」ボタンだけを表示する。
    if (_controller.isCompleted && _navigatedToReveal) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          FilledButton(onPressed: widget.onSpinAgain, child: const Text('もう一度ガチャを回す')),
        ],
      );
    }

    // Interval(始まり, 終わり) = 全体の進行度tのうち、この区間だけを取り出して改めて0.0〜1.0として扱うためのヘルパー。
    // curveを指定すると等速ではなく「だんだん速く/遅く」といった動きの緩急(イージング)をつけられる。
    // ここでは、本体が押し込まれる動き(0.0〜0.12の区間)だけを取り出している。
    final pressT = Interval(0.0, 0.12, curve: Curves.easeInOut).transform(t);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GachaMachine(pressT: pressT), // ガチャ本体のイラスト(押し込みアニメつき)
        SizedBox(
          height: 170,
          child: Stack(
            // Stack = 子要素を重ねて表示するレイアウト部品。カプセルたちを同じ場所を起点に重ねて表示し、位置をずらして飛び出す演出を作る。
            alignment: Alignment.topCenter,
            children: [
              _buildBurstFlash(t), // バースト瞬間の光(モック: 演出をリッチにする追加分)
              _buildBigCapsule(t), // 排出される大きな1個のカプセル(バーストするまで)List.generate(人数, ...) = 候補の人数分だけウィジェットを作る。
              // ...(スプレッド演算子)でそのリストの中身をchildrenに展開している。
              ...List.generate(widget.candidates.length, (i) => _buildFlyingCapsule(t, i)),
              _buildSparkleBurst(t), // バーストで飛び散る火花(モック: 演出をリッチにする追加分)
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(_statusLabel(t)), // 今の進行度に応じた案内テキスト
      ],
    );
  }

  // 進行度tに応じて、画面下部に表示する案内文を切り替える。
  String _statusLabel(double t) {
    if (t < 0.12) return 'ガチャが作動しています…';
    if (t < _machinePhaseEnd) return 'カプセルが出てきます…';
    return 'カプセルが震えています…';
  }

  // 排出口から出てくる「大きな1個のカプセル」を描画する。
  // 登場→震える→弾ける、という一連の動きをここで計算している。
  Widget _buildBigCapsule(double t) {
    // entranceT: 本体から出てくる登場アニメーションの進み具合(0〜1)。
    final entranceT = Interval(0.12, _machinePhaseEnd, curve: Curves.easeOutBack).transform(t);
    final oldT = _oldT(t);
    // shakeT: 震えるアニメーションの進み具合。
    final shakeT = Interval(0.0, 0.3, curve: Curves.linear).transform(oldT);
    // burstT: パンっと弾けて消える(バースト)アニメーションの進み具合。
    final burstT = Interval(0.3, 0.4, curve: Curves.easeOut).transform(oldT);

    // 登場中は少しずつ不透明に、バースト中はだんだん透明になって消える。
    final opacity = t < _machinePhaseEnd ? entranceT : (1 - burstT).clamp(0.0, 1.0);
    if (opacity <= 0) return const SizedBox.shrink(); // 完全に透明なら何も描画しない(無駄な描画を避ける)
    // scale: カプセルの大きさの倍率。バースト時に一瞬膨らませて弾けた感じを出す。
    final scale = t < _machinePhaseEnd ? entranceT : 1 + burstT * 1.5;
    // wobble: sin波を使って左右に小刻みに震える横方向のズレ量を作る。
    // (1 - shakeT)を掛けることで、震え幅が時間とともにだんだん収まっていくようにしている。
    final wobble = t < _machinePhaseEnd ? 0.0 : sin(shakeT * pi * 10) * 6 * (1 - shakeT);

    return Transform.translate(
      // Transform.translate = 子要素を指定したoffset(x,y)の分だけ平行移動させる。
      offset: Offset(wobble, 8),
      child: Opacity(
        // Opacity = 子要素の不透明度(0=完全に透明、1=不透明)を指定する。
        opacity: opacity.clamp(0.0, 1.0),
        // Transform.scale = 子要素を指定した倍率で拡大・縮小する。
        child: Transform.scale(scale: scale, child: const _Capsule(size: 72)),
      ),
    );
  }

  // モック: 演出をリッチにする追加分。バーストの瞬間に一瞬だけ光る円を描画する(パッと明るくなってすぐ消える)。
  Widget _buildBurstFlash(double t) {
    final oldT = _oldT(t);
    // flashT: 0.28〜0.45の間だけ光らせる(カプセルがバーストするタイミングに合わせている)。
    final flashT = Interval(0.28, 0.45, curve: Curves.easeOut).transform(oldT);
    if (flashT <= 0 || flashT >= 1) return const SizedBox.shrink();
    final opacity = (1 - flashT) * 0.85; // 出た瞬間が一番明るく、すぐ透明になっていく
    final scale = 0.4 + flashT * 2.0; // だんだん大きく広がっていく
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: 90,
          height: 90,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.amberAccent),
        ),
      ),
    );
  }

  // モック: 演出をリッチにする追加分。バーストの瞬間に小さな火花が放射状に飛び散る演出。
  Widget _buildSparkleBurst(double t) {
    final oldT = _oldT(t);
    // sparkleT: 0.28〜0.55の間で火花が外側へ広がっていく進み具合。
    final sparkleT = Interval(0.28, 0.55, curve: Curves.easeOut).transform(oldT);
    if (sparkleT <= 0) return const SizedBox.shrink();
    final opacity = (1 - sparkleT).clamp(0.0, 1.0);
    if (opacity <= 0) return const SizedBox.shrink();
    const sparkleCount = 8; // 火花の数
    return Stack(
      alignment: Alignment.topCenter,
      // 8個の火花を均等な角度(2π/8ずつ)に配置し、進み具合に応じて外側へ飛ばす。
      children: List.generate(sparkleCount, (i) {
        final angle = (i / sparkleCount) * pi * 2;
        final distance = sparkleT * 70;
        final dx = cos(angle) * distance;
        final dy = 8 + sin(angle) * distance * 0.6; // 縦方向はやや潰して楕円状に広げる
        return Transform.translate(
          offset: Offset(dx, dy),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            ),
          ),
        );
      }),
    );
  }

  // i番目の候補のカプセルが、弧を描いて飛び出し、最後に割れて消えるまでを描画する。
  Widget _buildFlyingCapsule(double t, int i) {
    final oldT = _oldT(t);
    // 候補ごとに少しずつ開始タイミング(flyStart)をずらして、同時に飛ばずぱらぱらと順番に飛び出しているように見せている(i * 0.03がそのズレ)。
    final flyStart = 0.35 + i * 0.03;
    final flyEnd = flyStart + 0.35;
    if (oldT < flyStart) return const SizedBox.shrink(); // まだ飛び出す番でなければ非表示

    // flyT: 飛んでいる最中の進み具合(0〜1)。
    final flyT = Interval(flyStart, flyEnd, curve: Curves.easeOutCubic).transform(oldT);
    // crackT: 着地後、カプセルが割れて消えていく演出の進み具合。
    final crackStart = flyEnd + 0.05;
    final crackEnd = crackStart + 0.15;
    final crackT = Interval(crackStart, crackEnd, curve: Curves.easeOut).transform(oldT);

    // targetは_arcTargetsForで決めた「最終的な着地位置」。
    // flyTをかけることで、0(出発点)からtarget(着地点)まで徐々に移動させる。
    final target = _arcTargets[i];
    final x = target.dx * flyT;
    // arcLift: sin波を使い、飛んでいる途中だけ高さを持ち上げて「弧を描く」動きにする
    // (flyT=0や1では0、真ん中(flyT=0.5)あたりで最大に持ち上がる)。
    final arcLift = sin(flyT * pi) * 30;
    final y = 8 + target.dy * flyT - arcLift;
    // angle: 飛んでいる間にくるくる回転させる角度。着地点が左か右かで回転方向を変えている。
    final angle = flyT * pi * 2 * (target.dx.isNegative ? -1 : 1);
    // 割れる演出(crackT)が進むほど、少し縮みながら透明になって消える。
    final scale = (1 - 0.3 * crackT).clamp(0.0, 1.0);
    final opacity = (1 - crackT).clamp(0.0, 1.0);

    return Transform.translate(
      offset: Offset(x, y),
      child: Transform.rotate(
        // Transform.rotate = 子要素を指定した角度(ラジアン)だけ回転させる。
        angle: angle,
        child: Opacity(
          opacity: opacity,
          child: Transform.scale(scale: scale, child: _Capsule(size: 52, key: ValueKey(i))),
        ),
      ),
    );
  }
}

/// カプセルのイラスト素材(`assets/images/gacha_capsule.png`)を表示するだけの薄いラッパー。
/// 位置・回転・拡縮・フェードは呼び出し側(`_GachaSpinRevealAnimation`)が操作する。
// StatelessWidget = 自分では状態(変化するデータ)を持たない、シンプルなウィジェット。
// 表示に必要な値(size)はすべて外側(呼び出し元)から渡してもらう。
class _Capsule extends StatelessWidget {
  const _Capsule({required this.size, super.key});

  final double size; // カプセル画像の一辺の大きさ(幅・高さ共通)

  @override
  Widget build(BuildContext context) {
    // Image.asset = プロジェクト内の画像ファイルを表示する部品。
    // fit: BoxFit.contain = 縦横比を保ったまま、指定サイズの中に収まるように表示する。
    return Image.asset('assets/images/gacha_capsule.png', width: size, height: size, fit: BoxFit.contain);
  }
}

/// ガチャ本体のイラスト(`assets/images/gacha_machine.png`)。`pressT`(0→1)は作動する瞬間に少しグッと押し込まれて戻る、Y方向のスカッシュ量を表す。
class _GachaMachine extends StatelessWidget {
  const _GachaMachine({required this.pressT});

  final double pressT; // 押し込みアニメーションの進み具合(0〜1)

  @override
  Widget build(BuildContext context) {
    // sin(pressT * pi)は0→1→0のように、途中で山になって戻ってくる形になる。
    // これを使って「一瞬ぺちゃんこに潰れて、また元の高さに戻る」動き(スカッシュ)を縦方向の縮尺(scaleY)として表現している。
    final squash = 1 - 0.06 * sin(pressT * pi);
    return Transform.scale(
      scaleY: squash, // 縦方向だけを縮める(横方向scaleXは変えない)
      alignment: Alignment.bottomCenter, // 下端を基準に縮めるので、台の位置がずれて見えない
      child: Image.asset('assets/images/gacha_machine.png', width: 150, fit: BoxFit.contain),
    );
  }
}
