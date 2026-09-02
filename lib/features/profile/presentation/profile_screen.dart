import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/sex.dart';
import '../../../core/media/image_orientation.dart';
import '../../../core/network/bloom_api_exception.dart';
import '../../../core/profile/profile_option_list_provider.dart';
import '../../../core/router/app_routes.dart';
import '../application/profile_controller.dart';
import '../domain/profile_data.dart';

enum _ProfileScreenMode { view, edit }

/// 写真スロット(1〜3)ごとの「保存する」を押すまでの保留状態。
/// キーが無いスロットは「変更なし」(サーバー値のまま)を意味する。
sealed class _PendingPhotoChange {
  const _PendingPhotoChange();
}

class _PendingPhotoReplace extends _PendingPhotoChange {
  const _PendingPhotoReplace(this.bytes);
  final Uint8List bytes;
}

class _PendingPhotoDelete extends _PendingPhotoChange {
  const _PendingPhotoDelete();
}

/// プロフィール作成/編集画面(共通)。
/// - 新規登録直後(スキップ可能な任意ステップ、[isOnboarding]=true)は今まで通り
///   最初から編集フォームで開く。
/// - マイページの「プロフィールを確認・編集」から開いた場合([isOnboarding]=false、
///   デフォルト)は、まず閲覧専用の表示にし、「編集する」を押すと編集フォームに切り替わる。
/// - 写真の追加・削除も、他の項目と同様に「保存する」を押すまでサーバーに反映されない
///   (選択中の変更はローカルで保持するだけ)。
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, this.isOnboarding = false});

  final bool isOnboarding;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  static const _coral = Color(0xFFF2828C);
  static const _coralDark = Color(0xFFE96B76);
  static const _onSurface = Color(0xFF1C1B1F);
  static const _onSurfaceVariant = Color(0xFF5B5652);
  static const _outlineVariant = Color(0xFFE7E1DC);
  static const _photoPlaceholderBg = Color(0xFFFBE6DA);
  static const _photoPlaceholderIcon = Color(0xFFB98E72);

  final _usernameController = TextEditingController();
  String? _ageId;
  String? _incomeId;
  String? _addressId;
  bool _rejectMatchingMailFlag = false;
  bool _initialized = false;

  late _ProfileScreenMode _mode = widget.isOnboarding ? _ProfileScreenMode.edit : _ProfileScreenMode.view;
  final Map<int, _PendingPhotoChange> _pendingPhotoChanges = {};

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // 画面表示のたびではなく、データが初めて届いた時だけフォームへ反映する(以降はローカルの編集内容を保持し、サーバーからの再取得で上書きしない)。
  void _initializeFrom(ProfileData data) {
    if (_initialized) return;
    _initialized = true;
    _resetEditStateFrom(data);
  }

  // 編集内容(写真の保留分を含む)をサーバー値に戻す。「編集する」を初めて押した時と、「編集をやめる」時の両方から呼ばれる。
  void _resetEditStateFrom(ProfileData data) {
    _usernameController.text = data.username;
    _ageId = data.ageId;
    _incomeId = data.incomeId;
    _addressId = data.addressId;
    _rejectMatchingMailFlag = data.rejectMatchingMailFlag;
    _pendingPhotoChanges.clear();
  }

  void _startEditing() => setState(() => _mode = _ProfileScreenMode.edit);

  void _cancelEditing(ProfileData data) {
    _resetEditStateFrom(data);
    setState(() => _mode = _ProfileScreenMode.view);
  }

  Future<void> _pickPhoto(int slot) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1440,
      maxHeight: 1440,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    setState(() => _pendingPhotoChanges[slot] = _PendingPhotoReplace(normalizeJpegOrientation(bytes)));
  }

  void _removePhoto(int slot, String? serverUrl) {
    setState(() {
      // 差し替え予定だっただけなら、まだサーバーには何も送っていないので取り消すだけでよい。
      if (_pendingPhotoChanges[slot] is _PendingPhotoReplace) {
        _pendingPhotoChanges.remove(slot);
      } else if (serverUrl != null) {
        _pendingPhotoChanges[slot] = const _PendingPhotoDelete();
      }
    });
  }

  Future<void> _save() async {
    final notifier = ref.read(profileControllerProvider.notifier);

    // 写真の保留分をスロット順に1件ずつサーバーへ反映する。どこかで失敗したら中断し、
    // 編集モードに留まる(成功済みの分はpendingから消えているので再度保存すれば続きから)。
    final pendingSlots = _pendingPhotoChanges.keys.toList()..sort();
    for (final slot in pendingSlots) {
      final change = _pendingPhotoChanges[slot]!;
      if (change is _PendingPhotoReplace) {
        final dataUri = 'data:image/jpeg;base64,${base64Encode(change.bytes)}';
        await notifier.uploadPhoto(slot, dataUri);
      } else {
        await notifier.deletePhoto(slot);
      }
      if (!mounted) return;
      if (ref.read(profileControllerProvider).hasError) return;
      setState(() => _pendingPhotoChanges.remove(slot));
    }

    // 写真がすべて成功したら、他項目をまとめて保存する。
    await notifier.save(
      ageId: _ageId,
      incomeId: _incomeId,
      addressId: _addressId,
      username: _usernameController.text.trim(),
      rejectMatchingMailFlag: _rejectMatchingMailFlag,
    );
    if (!mounted) return;
    if (ref.read(profileControllerProvider).hasError) return;

    if (widget.isOnboarding) {
      const HomeTabRoute().go(context);
    } else {
      setState(() => _mode = _ProfileScreenMode.view);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileControllerProvider);
    final data = profileAsync.value;

    if (data == null) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: profileAsync.hasError
                ? Text(_errorMessage(profileAsync.error!))
                : const CircularProgressIndicator(),
          ),
        ),
      );
    }

    final isBusy = profileAsync.isLoading;

    return PopScope(
      // 編集中(オンボーディングを除く)は、戻る操作をそのままpopさせず、まず編集を中断して閲覧モードに戻す。
      canPop: widget.isOnboarding || _mode == _ProfileScreenMode.view,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _cancelEditing(data);
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: _mode == _ProfileScreenMode.view
            ? _buildView(context, data)
            : _buildEdit(context, data, isBusy: isBusy, error: profileAsync.hasError ? profileAsync.error : null),
      ),
    );
  }

  // ============================================================
  // 閲覧モード
  // ============================================================

  Widget _buildView(BuildContext context, ProfileData data) {
    _initializeFrom(data);
    final photos = data.photoUrls.whereType<String>().toList();
    final ageLabel = _resolveOptionLabel(ref.watch(ageOptionListProvider), data.ageId, data.sex);
    final addressLabel = _resolveOptionLabel(ref.watch(addressOptionListProvider), data.addressId, data.sex);
    final incomeLabel = _resolveOptionLabel(ref.watch(incomeOptionListProvider), data.incomeId, data.sex);

    final titleParts = [data.username, ?ageLabel, ?addressLabel];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPhotoHeader(
              photos: photos,
              height: 420,
              leading: _circleIconButton(Icons.arrow_back, onTap: () => Navigator.of(context).pop()),
              trailing: _circleIconButton(Icons.settings_outlined, onTap: () => const SettingsRoute().push(context)),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titleParts.join(' '),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _onSurface),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (ageLabel != null) _buildChip(Icons.cake_outlined, ageLabel),
                      if (addressLabel != null) _buildChip(Icons.place_outlined, addressLabel),
                      if (incomeLabel != null) _buildChip(Icons.savings_outlined, '年収 $incomeLabel'),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1, color: _outlineVariant),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.mail_outline, size: 18, color: _onSurfaceVariant),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('マッチングのお知らせメール', style: TextStyle(fontSize: 14, color: _onSurfaceVariant)),
                      ),
                      Text(
                        data.rejectMatchingMailFlag ? '受け取らない' : '受け取る',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _onSurface),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _buildActionButton(label: '編集する', icon: Icons.edit_outlined, onTap: _startEditing),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: const Color(0xFFFBEFEA), borderRadius: BorderRadius.circular(18)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: _coralDark),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 13, color: _onSurface)),
        ],
      ),
    );
  }

  // ============================================================
  // 編集モード
  // ============================================================

  Widget _buildEdit(BuildContext context, ProfileData data, {required bool isBusy, Object? error}) {
    _initializeFrom(data);
    final heroPending = _pendingPhotoChanges[1];
    final heroBytes = heroPending is _PendingPhotoReplace ? heroPending.bytes : null;
    final heroUrl = heroPending == null ? data.photoUrls[0] : null;

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPhotoHeader(
              photos: heroUrl != null ? [heroUrl] : const [],
              memoryBytes: heroBytes,
              height: 280,
              leading: _circleIconButton(Icons.close, onTap: isBusy ? null : () => _cancelEditing(data)),
              trailing: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.photo_camera_outlined, size: 19, color: _coralDark),
                  onPressed: isBusy ? null : () => _pickPhoto(1),
                ),
              ),
              trailingAlignment: Alignment.bottomRight,
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: _buildSubPhotoSlot(2, data.photoUrls[1], isBusy)),
                      const SizedBox(width: 8),
                      Expanded(child: _buildSubPhotoSlot(3, data.photoUrls[2], isBusy)),
                    ],
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _usernameController,
                    enabled: !isBusy,
                    decoration: _fieldDecoration('ニックネーム'),
                  ),
                  const SizedBox(height: 12),
                  _buildOptionField(
                    label: '年齢',
                    optionsAsync: ref.watch(ageOptionListProvider),
                    sex: data.sex,
                    value: _ageId,
                    isBusy: isBusy,
                    onChanged: (id) => setState(() => _ageId = id),
                  ),
                  const SizedBox(height: 12),
                  _buildOptionField(
                    label: '年収',
                    optionsAsync: ref.watch(incomeOptionListProvider),
                    sex: data.sex,
                    value: _incomeId,
                    isBusy: isBusy,
                    onChanged: (id) => setState(() => _incomeId = id),
                  ),
                  const SizedBox(height: 12),
                  _buildOptionField(
                    label: 'お住まい',
                    optionsAsync: ref.watch(addressOptionListProvider),
                    sex: data.sex,
                    value: _addressId,
                    isBusy: isBusy,
                    onChanged: (id) => setState(() => _addressId = id),
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: _rejectMatchingMailFlag,
                    onChanged: isBusy ? null : (value) => setState(() => _rejectMatchingMailFlag = value ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    activeColor: _coralDark,
                    title: const Text(
                      'マッチングのお知らせメールを受け取らない',
                      style: TextStyle(fontSize: 14, color: _onSurface),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 4),
                    Text(_errorMessage(error), style: const TextStyle(color: Colors.red, fontSize: 13)),
                  ],
                  if (widget.isOnboarding) ...[
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: isBusy ? null : () => const HomeTabRoute().go(context),
                      child: const Text('あとで設定する'),
                    ),
                  ],
                ],
              ),
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: isBusy
                  ? const Center(child: CircularProgressIndicator())
                  : _buildActionButton(label: '保存する', onTap: _save),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubPhotoSlot(int slot, String? serverUrl, bool isBusy) {
    final pending = _pendingPhotoChanges[slot];
    final Widget? image = switch (pending) {
      _PendingPhotoReplace(:final bytes) => Image.memory(bytes, fit: BoxFit.cover),
      _PendingPhotoDelete() => null,
      null => serverUrl == null ? null : Image.network(serverUrl, fit: BoxFit.cover),
    };

    return AspectRatio(
      aspectRatio: 1,
      child: image == null
          ? InkWell(
              onTap: isBusy ? null : () => _pickPhoto(slot),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _outlineVariant, width: 1.5),
                ),
                child: const Center(child: Icon(Icons.add, color: _onSurfaceVariant)),
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(borderRadius: BorderRadius.circular(14), child: image),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: isBusy ? null : () => _removePhoto(slot, serverUrl),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: const Icon(Icons.cancel, size: 20, color: Colors.redAccent),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildOptionField({
    required String label,
    required AsyncValue<List<ProfileOption>> optionsAsync,
    required Sex sex,
    required String? value,
    required bool isBusy,
    required ValueChanged<String?> onChanged,
  }) {
    return optionsAsync.when(
      data: (options) {
        final filtered = options.where((option) => option.sex == sex.apiValue).toList();
        return DropdownButtonFormField<String>(
          initialValue: filtered.any((option) => option.id == value) ? value : null,
          decoration: _fieldDecoration(label),
          items: [for (final option in filtered) DropdownMenuItem(value: option.id, child: Text(option.item))],
          onChanged: isBusy ? null : onChanged,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('$labelの読み込みに失敗しました。'),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: _outlineVariant, width: 1.5),
    );
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: const TextStyle(color: _coralDark, fontWeight: FontWeight.w500, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(borderSide: const BorderSide(color: _coralDark, width: 1.5)),
    );
  }

  // ============================================================
  // 共通パーツ
  // ============================================================

  /// 写真ヘッダー(上角だけ丸め、暖色グラデーションの余白を覗かせる)。
  /// [photos]は表示するURL(閲覧モードは複数=ギャラリー、編集モードはメイン写真1枚のみ)。
  /// [memoryBytes]が指定されていれば、差し替え予定のローカル画像をそちらで優先表示する。
  Widget _buildPhotoHeader({
    required List<String> photos,
    required double height,
    Uint8List? memoryBytes,
    Widget? leading,
    Widget? trailing,
    Alignment trailingAlignment = Alignment.topRight,
  }) {
    return Container(
      padding: const EdgeInsets.only(top: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD3CE), Color(0xFFFFE9CE)],
        ),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: memoryBytes != null
                  ? Image.memory(memoryBytes, fit: BoxFit.cover)
                  : photos.isEmpty
                      ? Container(
                          color: _photoPlaceholderBg,
                          child: const Center(
                            child: Icon(Icons.person_outline, size: 90, color: _photoPlaceholderIcon),
                          ),
                        )
                      : PageView.builder(
                          itemCount: photos.length,
                          itemBuilder: (_, i) => Image.network(photos[i], fit: BoxFit.cover),
                        ),
            ),
          ),
          if (memoryBytes == null && photos.length > 1)
            Positioned(
              top: 24,
              left: 16,
              right: 16,
              child: Row(
                children: List.generate(
                  photos.length,
                  (i) => Expanded(
                    child: Container(
                      height: 3,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i == 0 ? Colors.white : Colors.white38,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (leading != null) Positioned(top: 16, left: 16, child: leading),
          if (trailing != null)
            Positioned(
              top: trailingAlignment == Alignment.topRight ? 16 : null,
              right: 16,
              bottom: trailingAlignment == Alignment.bottomRight ? 12 : null,
              child: trailing,
            ),
        ],
      ),
    );
  }

  Widget _circleIconButton(IconData icon, {required VoidCallback? onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.28),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 44, height: 44, child: Icon(icon, size: 18, color: Colors.white)),
      ),
    );
  }

  Widget _buildActionButton({required String label, IconData? icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(28),
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: const LinearGradient(colors: [_coral, _coralDark]),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 18, color: Colors.white), const SizedBox(width: 8)],
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white)),
            ],
          ),
        ),
      ),
    );
  }

  // 相手が持っている「選択肢のID」から、実際に画面に表示する日本語の文言を選択肢一覧の中から探して返す。
  // 見つからない場合(idが未設定/一覧未取得/該当なし)はnullを返す。
  String? _resolveOptionLabel(AsyncValue<List<ProfileOption>> optionsAsync, String? id, Sex sex) {
    if (id == null) return null;
    final options = optionsAsync.value;
    if (options == null) return null;
    final matching = options.where((option) => option.sex == sex.apiValue && option.id == id);
    return matching.isEmpty ? null : matching.first.item;
  }

  String _errorMessage(Object error) =>
      error is BloomApiException ? error.errorDetail : '通信状態を確認してください。';
}
