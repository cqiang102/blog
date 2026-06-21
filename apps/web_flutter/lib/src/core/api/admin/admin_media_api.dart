import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../models.dart';
import '../api_client_base.dart';

/// 管理后台 AdminMediaApi 接口。
mixin AdminMediaApi on ApiClientBase {
  /// 获取管理后台媒体列表
  Future<PageResult<AdminMediaItem>> fetchAdminMedia({
    required String accessToken,
    String? contentId,
    int page = 0,
    int size = 80,
  }) async {
    final data = await get(
      '/admin/media-assets',
      accessToken: accessToken,
      queryParameters: {
        if (contentId != null && contentId.isNotEmpty) 'contentId': contentId,
        'page': page.toString(),
        'size': size.toString(),
      },
    );
    return pageResult(data, AdminMediaItem.fromJson);
  }

  /// 创建管理后台媒体
  Future<AdminMediaItem> createAdminMedia({
    required String accessToken,
    required AdminMediaDraft draft,
  }) async {
    final data = await post(
      '/admin/media-assets',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminMediaItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 上传管理后台媒体文件
  Future<AdminMediaItem> uploadAdminMedia({
    required String accessToken,
    required Uint8List bytes,
    required String filename,
    required MediaAssetType type,
    String contentId = '',
  }) async {
    final formData = FormData.fromMap({
      if (contentId.isNotEmpty) 'contentId': contentId,
      'type': type.apiValue,
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final data = await send(
      'POST',
      '/admin/media-assets/upload',
      accessToken: accessToken,
      formData: formData,
    );
    return AdminMediaItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 更新管理后台媒体
  Future<AdminMediaItem> updateAdminMedia({
    required String accessToken,
    required String id,
    required AdminMediaDraft draft,
  }) async {
    final data = await put(
      '/admin/media-assets/$id',
      accessToken: accessToken,
      body: draft.toJson(),
    );
    return AdminMediaItem.fromJson((data as Map).cast<String, dynamic>());
  }

  /// 删除管理后台媒体
  Future<void> deleteAdminMedia({
    required String accessToken,
    required String id,
  }) async {
    await delete('/admin/media-assets/$id', accessToken: accessToken);
  }

  /// 设置内容封面
  Future<AdminContentItem> setAdminContentCover({
    required String accessToken,
    required String contentId,
    required String mediaId,
  }) async {
    final data = await put(
      '/admin/contents/$contentId/cover/$mediaId',
      accessToken: accessToken,
      body: const {},
    );
    return AdminContentItem.fromJson((data as Map).cast<String, dynamic>());
  }
}
