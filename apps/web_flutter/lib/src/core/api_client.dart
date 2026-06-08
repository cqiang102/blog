// API 客户端
// 组合所有 API 模块，提供统一的 API 调用接口

import 'package:dio/dio.dart';

import 'api/api_client_base.dart';
import 'api/admin_api.dart';
import 'api/ai_api.dart';
import 'api/auth_api.dart';
import 'api/content_api.dart';
import 'api/friends_api.dart';
import 'api/user_api.dart';

export 'api/api_client_base.dart' show apiBaseUrl;
export 'api/api_exception.dart';

/// 博客 API 客户端
/// 组合所有 API 模块，提供统一的 API 调用接口
class BlogApiClient = ApiClientBase with AuthApi, ContentApi, UserApi, AiApi, AdminApi, FriendsApi;

/// 创建 BlogApiClient 实例
BlogApiClient createBlogApiClient({String? baseUrl}) {
  final dio = Dio();
  return BlogApiClient(dio: dio, baseUrl: baseUrl ?? apiBaseUrl);
}
