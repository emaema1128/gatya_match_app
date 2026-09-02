import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/bloom_api_exception.dart';
import '../../../core/router/app_routes.dart';
import '../application/profile_controller.dart';
import '../domain/profile_data.dart';

/// マイページタブのホーム画面。自分の写真・「プロフィールを確認・編集」への導線・
/// 残ポイント・本人確認の案内・お知らせを表示する。
///
/// 「本人確認」バナーと「お知らせ」一覧は、対応するサーバーAPIが今のところ
/// 存在しないため、この画面では静的な(タップしても何も起きない)表示に
/// とどめている。バックエンド対応が決まり次第、実データに置き換える想定。
class ProfileHomeScreen extends ConsumerWidget {
  const ProfileHomeScreen({super.key});

  static const _coral = Color(0xFFF2828C);
  static const _coralDark = Color(0xFFE96B76);
  static const _onSurface = Color(0xFF1C1B1F);
  static const _onSurfaceVariant = Color(0xFF5B5652);
  static const _outlineVariant = Color(0xFFE7E1DC);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileControllerProvider);

    return Scaffold(
      body: SafeArea(
        child: profileAsync.when(
          data: (data) => _buildContent(context, data),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text(
              error is BloomApiException ? error.errorDetail : '通信状態を確認してください。',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ProfileData data) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(context, data),
          _buildBalance(context, data),
          const SizedBox(height: 20),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildVerificationBanner()),
          const SizedBox(height: 24),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: _buildNotices(context)),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ProfileData data) {
    final photoUrl = data.photoUrls.isNotEmpty ? data.photoUrls[0] : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFD3CE), Color(0xFFFFE9CE)],
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 0),
              color: const Color(0xFFFBE6DA),
            ),
            clipBehavior: Clip.antiAlias,
            child: photoUrl == null
                ? const Icon(Icons.person_outline, size: 46, color: Color(0xFFB98E72))
                : Image.network(photoUrl, fit: BoxFit.cover),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Material(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(28),
              child: InkWell(
                borderRadius: BorderRadius.circular(28),
                onTap: () => const MyProfileRoute().push(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.edit_outlined, size: 17, color: _onSurface),
                      const Expanded(
                        child: Text(
                          'プロフィールを確認・編集',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: _onSurface),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalance(BuildContext context, ProfileData data) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
      child: Column(
        children: [
          const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.monetization_on_outlined, size: 16, color: Color(0xFFB08B2A)),
              SizedBox(width: 6),
              Text('残ポイント', style: TextStyle(fontSize: 13, color: _onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 4),
          Text('${data.balance}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: _onSurface)),
        ],
      ),
    );
  }

  Widget _buildVerificationBanner() {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(colors: [_coral, _coralDark]),
      ),
      child: const Row(
        children: [
          Icon(Icons.badge_outlined, size: 20, color: Colors.white),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'お相手とのトーク前に本人確認をしましょう',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotices(BuildContext context) {
    const notices = [
      _NoticeItem(icon: Icons.visibility_outlined, iconBg: Color(0xFFFDE8E9), iconColor: _coralDark, text: '新しい足あとが届いています', unread: true),
      _NoticeItem(icon: Icons.campaign_outlined, iconBg: Color(0xFFFFF1DE), iconColor: Color(0xFFC98A2E), text: 'キャンペーンのお知らせ', unread: false),
      _NoticeItem(icon: Icons.build_outlined, iconBg: Color(0xFFEAE6FB), iconColor: Color(0xFF6750A4), text: 'メンテナンスのお知らせ', unread: false),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('お知らせ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _onSurface)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              for (var i = 0; i < notices.length; i++) ...[
                if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16, color: _outlineVariant),
                _buildNoticeRow(notices[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoticeRow(_NoticeItem item) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: item.iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(item.icon, size: 18, color: item.iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(item.text, style: const TextStyle(fontSize: 14, color: _onSurface))),
          if (item.unread)
            Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: _coralDark)),
        ],
      ),
    );
  }
}

class _NoticeItem {
  const _NoticeItem({required this.icon, required this.iconBg, required this.iconColor, required this.text, required this.unread});

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String text;
  final bool unread;
}
