// 友情链接 API
// 包含随机友情链接获取

import '../models.dart';
import 'api_client_base.dart';

/// 友情链接 API Mixin
mixin FriendApi on ApiClientBase {
  /// 获取随机友情链接
  Future<List<FriendLink>> fetchFriends() async {
    final data = await get('/friends/random');
    return decodeObjectList(data, FriendLink.fromJson);
  }
}
