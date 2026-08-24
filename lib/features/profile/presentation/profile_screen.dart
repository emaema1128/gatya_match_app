import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/sex.dart';
import '../../../core/network/bloom_api_exception.dart';
import '../../../core/profile/profile_option_list_provider.dart';
import '../../../core/router/app_routes.dart';
import '../application/profile_controller.dart';
import '../domain/profile_data.dart';

/// プロフィール作成/編集画面(共通)。
/// - 新規登録直後(スキップ可能な任意ステップ)とマイページからの編集の両方で使う
/// - age/income/address/ニックネーム/マッチングメール設定は「保存」ボタンでまとめて送信
/// - 写真(最大3枚)は選択・削除のたびに即時アップロード/削除
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _usernameController = TextEditingController();
  String? _ageId;
  String? _incomeId;
  String? _addressId;
  bool _rejectMatchingMailFlag = false;
  bool _initialized = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  // 画面表示のたびではなく、データが初めて届いた時だけフォームへ反映する
  // (以降はローカルの編集内容を保持し、サーバーからの再取得で上書きしない)。
  void _initializeFrom(ProfileData data) {
    if (_initialized) return;
    _initialized = true;
    _usernameController.text = data.username;
    _ageId = data.ageId;
    _incomeId = data.incomeId;
    _addressId = data.addressId;
    _rejectMatchingMailFlag = data.rejectMatchingMailFlag;
  }

  Future<void> _pickAndUploadPhoto(int slot) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1440,
      maxHeight: 1440,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
    if (!mounted) return;
    await ref.read(profileControllerProvider.notifier).uploadPhoto(slot, dataUri);
  }

  Future<void> _deletePhoto(int slot) async {
    await ref.read(profileControllerProvider.notifier).deletePhoto(slot);
  }

  Future<void> _save() async {
    await ref.read(profileControllerProvider.notifier).save(
          ageId: _ageId,
          incomeId: _incomeId,
          addressId: _addressId,
          username: _usernameController.text.trim(),
          rejectMatchingMailFlag: _rejectMatchingMailFlag,
        );
    if (!mounted) return;
    if (ref.read(profileControllerProvider).hasError) return;
    if (!Navigator.of(context).canPop()) {
      const HomeTabRoute().go(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileControllerProvider);
    final data = profileAsync.value;

    return Scaffold(
      appBar: AppBar(title: const Text('プロフィール')),
      body: SafeArea(
        child: data == null
            ? Center(
                child: profileAsync.hasError
                    ? Text(_errorMessage(profileAsync.error!))
                    : const CircularProgressIndicator(),
              )
            : _buildForm(context, data, isBusy: profileAsync.isLoading),
      ),
    );
  }

  Widget _buildForm(BuildContext context, ProfileData data, {required bool isBusy}) {
    _initializeFrom(data);
    final profileAsync = ref.watch(profileControllerProvider);
    final canPop = Navigator.of(context).canPop();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('写真', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _buildPhotoRow(data, isBusy),
          const SizedBox(height: 24),
          TextField(
            controller: _usernameController,
            enabled: !isBusy,
            decoration: const InputDecoration(labelText: 'ニックネーム'),
          ),
          const SizedBox(height: 20),
          _buildOptionDropdown(
            label: '年齢',
            optionsAsync: ref.watch(ageOptionListProvider),
            sex: data.sex,
            value: _ageId,
            isBusy: isBusy,
            onChanged: (id) => setState(() => _ageId = id),
          ),
          const SizedBox(height: 12),
          _buildOptionDropdown(
            label: '年収',
            optionsAsync: ref.watch(incomeOptionListProvider),
            sex: data.sex,
            value: _incomeId,
            isBusy: isBusy,
            onChanged: (id) => setState(() => _incomeId = id),
          ),
          const SizedBox(height: 12),
          _buildOptionDropdown(
            label: 'お住まい',
            optionsAsync: ref.watch(addressOptionListProvider),
            sex: data.sex,
            value: _addressId,
            isBusy: isBusy,
            onChanged: (id) => setState(() => _addressId = id),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            value: _rejectMatchingMailFlag,
            onChanged: isBusy ? null : (value) => setState(() => _rejectMatchingMailFlag = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('マッチングのお知らせメールを受け取らない'),
          ),
          const SizedBox(height: 24),
          if (isBusy)
            const Center(child: CircularProgressIndicator())
          else
            ElevatedButton(onPressed: _save, child: const Text('保存する')),
          if (profileAsync.hasError) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage(profileAsync.error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          if (!canPop) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: isBusy ? null : () => const HomeTabRoute().go(context),
              child: const Text('あとで設定する'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotoRow(ProfileData data, bool isBusy) {
    return Row(
      children: [
        for (var slot = 1; slot <= 3; slot++) ...[
          if (slot > 1) const SizedBox(width: 8),
          Expanded(child: _buildPhotoSlot(slot, data.photoUrls[slot - 1], isBusy)),
        ],
      ],
    );
  }

  Widget _buildPhotoSlot(int slot, String? url, bool isBusy) {
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: BorderRadius.circular(8),
            ),
            child: url == null
                ? IconButton(
                    onPressed: isBusy ? null : () => _pickAndUploadPhoto(slot),
                    icon: const Icon(Icons.add_a_photo_outlined),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(url, fit: BoxFit.cover),
                  ),
          ),
          if (url != null)
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                onPressed: isBusy ? null : () => _deletePhoto(slot),
                icon: const Icon(Icons.cancel, color: Colors.red),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOptionDropdown({
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
          decoration: InputDecoration(labelText: label),
          items: [
            for (final option in filtered) DropdownMenuItem(value: option.id, child: Text(option.item)),
          ],
          onChanged: isBusy ? null : onChanged,
        );
      },
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('$labelの読み込みに失敗しました。'),
    );
  }

  String _errorMessage(Object error) =>
      error is BloomApiException ? error.errorDetail : '通信状態を確認してください。';
}
