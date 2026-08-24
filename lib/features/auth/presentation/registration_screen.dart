import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/sex.dart';
import '../../../core/network/bloom_api_exception.dart';
import '../../../core/region/area_list_provider.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/storage/device_id_provider.dart';
import '../application/registration_controller.dart';

/// 新規登録画面
/// - 性別・居住地域(地方/都道府県/市区町村)・自己紹介(PR文)を入力して登録する
/// - 利用規約に同意するチェックボックスを設置
class RegistrationScreen extends ConsumerStatefulWidget {
  const RegistrationScreen({super.key});

  @override
  ConsumerState<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends ConsumerState<RegistrationScreen> {
  final _commentController = TextEditingController();

  Sex? _sex;
  String? _regionId;
  String? _prefectureId;
  String? _cityId;
  bool _agreedToTerms = false;

  @override
  void initState() {
    super.initState();
    _commentController.addListener(_onFieldChanged);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _onFieldChanged() => setState(() {});

  void _onRegionChanged(String? value) => setState(() {
        _regionId = value;
        _prefectureId = null;
        _cityId = null;
      });

  void _onPrefectureChanged(String? value) => setState(() {
        _prefectureId = value;
        _cityId = null;
      });

  bool get _canSubmit =>
      _sex != null &&
      _regionId != null &&
      _prefectureId != null &&
      _cityId != null &&
      _commentController.text.trim().isNotEmpty &&
      _agreedToTerms;

  void _submit() {
    ref.read(registrationControllerProvider.notifier).submit(
          sex: _sex!,
          region: _regionId!,
          prefecture: _prefectureId!,
          city: _cityId!,
          comment: _commentController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    // 登録成功(loading→data、エラーなし)を検知したら、リダイレクトロジックに任せず
    // 明示的にプロフィール入力画面へ遷移する(スキップ可能な任意ステップとして提示)。
    ref.listen(registrationControllerProvider, (previous, next) {
      if (previous is AsyncLoading && next is AsyncData) {
        const ProfileRoute().go(context);
      }
    });

    final registrationState = ref.watch(registrationControllerProvider);
    final areaListAsync = ref.watch(areaListProvider);
    final isLoading = registrationState.isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('新規登録')),
      body: SafeArea(
        child: areaListAsync.when(
          data: (areaList) => _buildForm(context, areaList, registrationState, isLoading),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _buildAreaListError(context, error),
        ),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    AreaList areaList,
    AsyncValue<void> registrationState,
    bool isLoading,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('性別', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          SegmentedButton<Sex>(
            segments: const [
              ButtonSegment(value: Sex.male, label: Text('男性')),
              ButtonSegment(value: Sex.female, label: Text('女性')),
            ],
            selected: _sex == null ? const {} : {_sex!},
            emptySelectionAllowed: true,
            onSelectionChanged: isLoading
                ? null
                : (selected) => setState(() => _sex = selected.isEmpty ? null : selected.first),
          ),
          const SizedBox(height: 20),
          Text('お住まいの地域', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _regionId,
            decoration: const InputDecoration(labelText: '地方'),
            items: [
              for (final region in areaList.regions)
                DropdownMenuItem(value: region.id, child: Text(region.name)),
            ],
            onChanged: isLoading ? null : _onRegionChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _prefectureId,
            decoration: const InputDecoration(labelText: '都道府県'),
            items: [
              for (final prefecture in areaList.prefecturesOf(_regionId ?? ''))
                DropdownMenuItem(value: prefecture.id, child: Text(prefecture.name)),
            ],
            onChanged: (isLoading || _regionId == null) ? null : _onPrefectureChanged,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _cityId,
            decoration: const InputDecoration(labelText: '市区町村'),
            items: [
              for (final city in areaList.citiesOf(_prefectureId ?? ''))
                DropdownMenuItem(value: city.id, child: Text(city.name)),
            ],
            onChanged: (isLoading || _prefectureId == null)
                ? null
                : (value) => setState(() => _cityId = value),
          ),
          const SizedBox(height: 20),
          Text('自己紹介 (PR文)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _commentController,
            enabled: !isLoading,
            minLines: 3,
            maxLines: 5,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              hintText: 'あなたの魅力を書いてみましょう',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          CheckboxListTile(
            value: _agreedToTerms,
            onChanged: isLoading ? null : (value) => setState(() => _agreedToTerms = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text('利用規約に同意する'),
            subtitle: const Text(
              // TODO: 実際の利用規約URLが決まり次第差し替える。
              'https://bloom-developer.com/terms (仮)',
            ),
          ),
          const SizedBox(height: 12),
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            ElevatedButton(
              onPressed: _canSubmit ? _submit : null,
              child: const Text('登録する'),
            ),
          if (registrationState.hasError) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage(registrationState.error!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAreaListError(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              error is BloomApiException ? error.errorDetail : '地域情報の読み込みに失敗しました。',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
            // TODO(debug): 原因特定のための一時的な詳細表示。特定でき次第削除する。
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => ref.invalidate(areaListProvider),
              child: const Text('再読み込み'),
            ),
          ],
        ),
      ),
    );
  }

  String _errorMessage(Object error) {
    if (error is DeviceAlreadyRegisteredException) {
      return 'この端末では既に登録済みです。ログインをお試しください。';
    }
    if (error is DeviceIdUnavailableException) {
      return '端末情報を取得できませんでした。しばらくしてから再度お試しください。';
    }
    if (error is BloomApiException) {
      return error.errorDetail;
    }
    return '登録に失敗しました。通信状態を確認してください。';
  }
}
