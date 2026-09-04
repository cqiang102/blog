import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/link.dart';

import '../../../widgets/widgets.dart';
import '../../../core/api_client.dart';
import '../../../core/constants.dart';
import '../../../core/media_url.dart';
import '../../../core/models.dart';
import '../../../theme/app_spacing.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/app_design_tokens.dart';
import '../application/home_feed_provider.dart';

part 'home_cover.dart';
part 'home_feed.dart';
part 'home_footer.dart';
part 'home_hero.dart';
part 'home_states.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final feed = ref.watch(homeFeedProvider);

    return AppPageFrame(
      child: CustomScrollView(
        slivers: [
          const SliverAppBar(
            toolbarHeight: 72,
            title: Text('首页'),
            actions: [
              AppThemeToggle(),
              SizedBox(width: AppSpacing.sm),
            ],
          ),
          ...feed.when(
            loading: () => const [
              SliverFillRemaining(hasScrollBody: false, child: _LoadingState()),
            ],
            error: (error, stackTrace) => [
              SliverFillRemaining(
                hasScrollBody: false,
                child: _ErrorState(
                  message: userFacingErrorMessage(error),
                  onRetry: () => ref.invalidate(homeFeedProvider),
                ),
              ),
            ],
            data: (data) => _buildContent(data),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent(HomeFeed data) {
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          0,
        ),
        sliver: SliverToBoxAdapter(child: _HomeHero(featured: data.featured)),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        sliver: SliverToBoxAdapter(
          child: AppSectionHeader(
            title: '最近更新',
            subtitle: '新写下的文章、照片与生活片段',
            actionLabel: '查看全部',
            onAction: () => context.go('/contents'),
          ),
        ),
      ),
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
      if (data.latest.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: _LatestContent(contents: data.latest),
        )
      else
        const SliverToBoxAdapter(child: _EmptyState(message: '还没有发布内容')),
      if (data.mostLiked.isNotEmpty) ...[
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
        const SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: AppSectionHeader(title: '大家喜欢', subtitle: '被读者收藏和点赞最多的内容'),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.md)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          sliver: SliverToBoxAdapter(
            child: _PopularList(contents: data.mostLiked),
          ),
        ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xxl)),
      const SliverPadding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.xxl,
        ),
        sliver: SliverToBoxAdapter(child: _HomeFooter()),
      ),
    ];
  }
}
