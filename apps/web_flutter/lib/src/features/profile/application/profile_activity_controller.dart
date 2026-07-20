import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/models.dart';
import '../../../state/api_providers.dart';

enum ProfileActivityType {
  comments('comments'),
  likes('likes'),
  views('views');

  const ProfileActivityType(this.apiValue);

  final String apiValue;
}

final profileActivityProvider = NotifierProvider.autoDispose
    .family<
      ProfileActivityController,
      ProfileActivityState,
      ProfileActivityType
    >(ProfileActivityController.new);

class ProfileActivityState {
  const ProfileActivityState({
    this.items = const [],
    this.currentPage = 0,
    this.total = 0,
    this.isLoading = false,
    this.hasMore = true,
    this.error,
  });

  final List<UserActivity> items;
  final int currentPage;
  final int total;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  ProfileActivityState copyWith({
    List<UserActivity>? items,
    int? currentPage,
    int? total,
    bool? isLoading,
    bool? hasMore,
    String? error,
    bool clearError = false,
  }) {
    return ProfileActivityState(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      total: total ?? this.total,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ProfileActivityController extends Notifier<ProfileActivityState> {
  ProfileActivityController(this.type);

  static const _pageSize = 20;
  final ProfileActivityType type;
  bool _disposed = false;
  int _generation = 0;
  final Set<String> _deletedIds = <String>{};

  @override
  ProfileActivityState build() {
    _disposed = false;
    _deletedIds.clear();
    ref.onDispose(() {
      _disposed = true;
      _generation++;
    });
    return const ProfileActivityState();
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) {
      state = state.copyWith(error: '请先登录', hasMore: false);
      return;
    }

    final generation = _generation;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await ref
          .read(apiClientProvider)
          .fetchMyActivity(
            accessToken: token,
            type: type.apiValue,
            page: state.currentPage,
            size: _pageSize,
          );
      if (_disposed || generation != _generation) return;
      final items = [
        ...state.items,
        ...result.items.where((item) => !_deletedIds.contains(item.id)),
      ];
      state = state.copyWith(
        items: items,
        currentPage: state.currentPage + 1,
        total: result.total,
        hasMore: items.length < result.total,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      if (!_disposed && generation == _generation) {
        state = state.copyWith(
          isLoading: false,
          error: userFacingErrorMessage(error),
        );
      }
    }
  }

  Future<void> retry() async {
    _generation++;
    state = const ProfileActivityState();
    await loadMore();
  }

  Future<String?> delete(UserActivity item) async {
    final token = ref.read(authControllerProvider).accessToken;
    if (token == null) return '请先登录';
    try {
      await ref
          .read(apiClientProvider)
          .deleteMyActivity(
            accessToken: token,
            type: type.apiValue,
            id: item.id,
          );
      if (!_disposed) {
        // Invalidate any page request that started before the delete completed.
        // The tombstone also protects against a briefly stale subsequent page.
        _generation++;
        _deletedIds.add(item.id);
        final items = state.items
            .where((current) => current.id != item.id)
            .toList();
        final total = state.total > 0 ? state.total - 1 : 0;
        state = state.copyWith(
          items: items,
          total: total,
          isLoading: false,
          hasMore: items.length < total,
        );
      }
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (error) {
      return userFacingErrorMessage(error);
    }
  }
}
