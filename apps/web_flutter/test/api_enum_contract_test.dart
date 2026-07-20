import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/core/models/enums.dart';

void main() {
  group('backend enum contract', () {
    test('content types stay aligned', () {
      expect(
        ContentType.values.map((value) => value.apiValue).toSet(),
        _backendEnumValues('content/domain/model/ContentType.java'),
      );
    });

    test('content statuses stay aligned', () {
      expect(
        ContentStatus.values.map((value) => value.apiValue).toSet(),
        _backendEnumValues('content/domain/model/ContentStatus.java'),
      );
    });

    test('media types stay aligned', () {
      expect(
        MediaAssetType.values.map((value) => value.apiValue).toSet(),
        _backendEnumValues('content/domain/model/MediaAssetType.java'),
      );
    });

    test('comment statuses stay aligned', () {
      expect(
        AdminCommentStatus.values.map((value) => value.apiValue).toSet(),
        _backendEnumValues('interaction/domain/model/CommentStatus.java'),
      );
    });

    test('user roles and statuses stay aligned', () {
      expect(
        AdminUserRole.values.map((value) => value.apiValue).toSet(),
        _backendEnumValues('shared/model/Role.java'),
      );
      expect(
        AdminUserStatus.values.map((value) => value.apiValue).toSet(),
        _backendEnumValues('user/domain/model/UserStatus.java'),
      );
    });

    test('knowledge sources stay aligned', () {
      expect(
        KnowledgeSourceType.values.map((value) => value.apiValue).toSet(),
        _backendEnumValues(
          'ai/knowledge/domain/model/KnowledgeSourceType.java',
        ),
      );
    });

    test('AI message roles stay aligned', () {
      expect(
        AiChatMessageRole.values
            .map((value) => value.name.toUpperCase())
            .toSet(),
        _backendEnumValues('ai/chat/domain/model/AiMessageRole.java'),
      );
    });
  });
}

Set<String> _backendEnumValues(String relativePath) {
  final path = '../api/src/main/java/com/caoqiang/blog/$relativePath';
  final source = File(path);
  if (!source.existsSync()) {
    fail('Backend enum source not found: ${source.absolute.path}');
  }

  // Java permits the final enum constant to omit both the comma and semicolon.
  final constant = RegExp(r'^\s{4}([A-Z][A-Z0-9_]*)[,;]?\s*$', multiLine: true);
  final values = constant
      .allMatches(source.readAsStringSync())
      .map((match) => match.group(1)!)
      .toSet();
  if (values.isEmpty) {
    fail('No enum constants found in ${source.absolute.path}');
  }
  return values;
}
