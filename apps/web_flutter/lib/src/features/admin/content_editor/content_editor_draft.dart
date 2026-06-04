import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_editor_state.dart';

/// 草稿持久化服务
/// 使用内容 ID 作为 key，避免多内容草稿冲突
class ContentEditorDraftService {
  ContentEditorDraftService(this._prefs);

  final SharedPreferences _prefs;

  static const String _keyPrefix = 'content_draft_';

  /// 生成草稿 key
  String _getDraftKey(String? contentId) {
    return '$_keyPrefix${contentId ?? "new"}';
  }

  /// 加载草稿
  Future<ContentEditorState?> loadDraft(String? contentId) async {
    try {
      final key = _getDraftKey(contentId);
      final draftJson = _prefs.getString(key);
      if (draftJson == null) return null;

      final json = jsonDecode(draftJson) as Map<String, dynamic>;
      return ContentEditorState.fromJson(json);
    } catch (e) {
      debugPrint('Failed to load draft: $e');
      return null;
    }
  }

  /// 保存草稿
  Future<bool> saveDraft(String? contentId, ContentEditorState state) async {
    try {
      final key = _getDraftKey(contentId);
      final json = state.toJson();
      await _prefs.setString(key, jsonEncode(json));
      return true;
    } catch (e) {
      debugPrint('Failed to save draft: $e');
      return false;
    }
  }

  /// 清除草稿
  Future<bool> clearDraft(String? contentId) async {
    try {
      final key = _getDraftKey(contentId);
      await _prefs.remove(key);
      return true;
    } catch (e) {
      debugPrint('Failed to clear draft: $e');
      return false;
    }
  }

  /// 清除所有草稿
  Future<void> clearAllDrafts() async {
    try {
      final keys = _prefs.getKeys().where((k) => k.startsWith(_keyPrefix));
      for (final key in keys) {
        await _prefs.remove(key);
      }
    } catch (e) {
      debugPrint('Failed to clear all drafts: $e');
    }
  }

  /// 检查是否有草稿
  bool hasDraft(String? contentId) {
    final key = _getDraftKey(contentId);
    return _prefs.containsKey(key);
  }
}
