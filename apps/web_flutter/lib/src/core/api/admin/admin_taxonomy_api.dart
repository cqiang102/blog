import '../../models.dart';
import '../api_client_base.dart';

/// 管理后台 AdminTaxonomyApi 接口。
mixin AdminTaxonomyApi on ApiClientBase {
  /// 获取管理后台标签列表
  Future<List<TagItem>> fetchAdminTags(String accessToken) async {
    final data = await get('/admin/tags', accessToken: accessToken);
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((item) => TagItem.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// 创建管理后台标签
  Future<TagItem> createAdminTag({
    required String accessToken,
    required TagDraft draft,
  }) async {
    final data = await post(
      '/admin/tags',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return TagItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 更新管理后台标签
  Future<TagItem> updateAdminTag({
    required String accessToken,
    required String id,
    required TagDraft draft,
  }) async {
    final data = await put(
      '/admin/tags/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return TagItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台标签
  Future<void> deleteAdminTag({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/tags/$id', accessToken: accessToken);
  }

  /// 获取管理后台友情链接列表
  Future<List<FriendLink>> fetchAdminFriends(String accessToken) async {
    final data = await get('/admin/friends', accessToken: accessToken);
    return (data as List? ?? const [])
        .whereType<Map>()
        .map((item) => FriendLink.fromJson(item.cast<String, dynamic>()))
        .toList();
  }

  /// 创建管理后台友情链接
  Future<FriendLink> createAdminFriend({
    required String accessToken,
    required FriendDraft draft,
  }) async {
    final data = await post(
      '/admin/friends',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return FriendLink.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 更新管理后台友情链接
  Future<FriendLink> updateAdminFriend({
    required String accessToken,
    required String id,
    required FriendDraft draft,
  }) async {
    final data = await put(
      '/admin/friends/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return FriendLink.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台友情链接
  Future<void> deleteAdminFriend({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/friends/$id', accessToken: accessToken);
  }
}
