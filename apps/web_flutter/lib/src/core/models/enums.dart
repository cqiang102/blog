// 枚举类型定义
// 包含所有业务枚举及其 API 值转换

/// 内容类型枚举
enum ContentType {
  /// Markdown 内容（合并了原来的 text 和 article）
  markdown,

  /// 图片
  image,

  /// 视频
  video;

  /// 转换为 API 使用的字符串值
  /// 新创建的内容统一使用 ARTICLE
  String get apiValue {
    return switch (this) {
      ContentType.markdown => 'ARTICLE',
      ContentType.image => 'IMAGE',
      ContentType.video => 'VIDEO',
    };
  }

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      ContentType.markdown => '文章',
      ContentType.image => '图片',
      ContentType.video => '视频',
    };
  }

  /// 从 API 字符串值转换为枚举
  static ContentType fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'ARTICLE' => ContentType.markdown,
      'IMAGE' => ContentType.image,
      'VIDEO' => ContentType.video,
      _ => ContentType.markdown,
    };
  }
}

/// 内容状态枚举
enum ContentStatus {
  /// 草稿
  draft,

  /// 已发布
  published,

  /// 已归档
  archived;

  /// 转换为 API 使用的字符串值
  String get apiValue {
    return switch (this) {
      ContentStatus.draft => 'DRAFT',
      ContentStatus.published => 'PUBLISHED',
      ContentStatus.archived => 'ARCHIVED',
    };
  }

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      ContentStatus.draft => '草稿',
      ContentStatus.published => '已发布',
      ContentStatus.archived => '已归档',
    };
  }

  /// 从 API 字符串值转换为枚举
  static ContentStatus fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'PUBLISHED' => ContentStatus.published,
      'ARCHIVED' => ContentStatus.archived,
      _ => ContentStatus.draft,
    };
  }
}

/// 媒体资源类型枚举
enum MediaAssetType {
  /// 图片
  image,

  /// 视频
  video,

  /// 文件
  file;

  /// 转换为 API 使用的字符串值
  String get apiValue {
    return switch (this) {
      MediaAssetType.image => 'IMAGE',
      MediaAssetType.video => 'VIDEO',
      MediaAssetType.file => 'FILE',
    };
  }

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      MediaAssetType.image => '图片',
      MediaAssetType.video => '视频',
      MediaAssetType.file => '文件',
    };
  }

  /// 从 API 字符串值转换为枚举
  static MediaAssetType fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'VIDEO' => MediaAssetType.video,
      'FILE' => MediaAssetType.file,
      _ => MediaAssetType.image,
    };
  }
}

/// 管理后台评论状态枚举
enum AdminCommentStatus {
  /// 可见
  visible,

  /// 已删除
  deleted;

  /// 转换为 API 使用的字符串值
  String get apiValue {
    return switch (this) {
      AdminCommentStatus.visible => 'VISIBLE',
      AdminCommentStatus.deleted => 'DELETED',
    };
  }

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      AdminCommentStatus.visible => '可见',
      AdminCommentStatus.deleted => '已删除',
    };
  }

  /// 从 API 字符串值转换为枚举
  static AdminCommentStatus fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'DELETED' => AdminCommentStatus.deleted,
      _ => AdminCommentStatus.visible,
    };
  }
}

/// 管理后台用户角色枚举
enum AdminUserRole {
  /// 普通用户
  user,

  /// 管理员
  admin;

  /// 转换为 API 使用的字符串值
  String get apiValue {
    return switch (this) {
      AdminUserRole.user => 'USER',
      AdminUserRole.admin => 'ADMIN',
    };
  }

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      AdminUserRole.user => '普通用户',
      AdminUserRole.admin => '管理员',
    };
  }

  /// 从 API 字符串值转换为枚举
  static AdminUserRole fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'ADMIN' => AdminUserRole.admin,
      _ => AdminUserRole.user,
    };
  }
}

/// 管理后台用户状态枚举
enum AdminUserStatus {
  /// 启用
  active,

  /// 禁用
  disabled;

  /// 转换为 API 使用的字符串值
  String get apiValue {
    return switch (this) {
      AdminUserStatus.active => 'ACTIVE',
      AdminUserStatus.disabled => 'DISABLED',
    };
  }

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      AdminUserStatus.active => '启用',
      AdminUserStatus.disabled => '禁用',
    };
  }

  /// 从 API 字符串值转换为枚举
  static AdminUserStatus fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'DISABLED' => AdminUserStatus.disabled,
      _ => AdminUserStatus.active,
    };
  }
}

/// 知识库文档来源类型枚举
enum KnowledgeSourceType {
  /// 手动录入
  manual,

  /// 网页
  url,

  /// 文件
  file,

  /// 内容引用
  content;

  /// 转换为 API 使用的字符串值
  String get apiValue {
    return switch (this) {
      KnowledgeSourceType.manual => 'MANUAL',
      KnowledgeSourceType.url => 'URL',
      KnowledgeSourceType.file => 'FILE',
      KnowledgeSourceType.content => 'CONTENT',
    };
  }

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      KnowledgeSourceType.manual => '手动录入',
      KnowledgeSourceType.url => '网页',
      KnowledgeSourceType.file => '文件',
      KnowledgeSourceType.content => '内容引用',
    };
  }

  /// 从 API 字符串值转换为枚举
  static KnowledgeSourceType fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'URL' => KnowledgeSourceType.url,
      'FILE' => KnowledgeSourceType.file,
      'CONTENT' => KnowledgeSourceType.content,
      _ => KnowledgeSourceType.manual,
    };
  }
}

/// AI 聊天消息角色枚举
enum AiChatMessageRole {
  /// 用户
  user,

  /// 助手
  assistant,

  /// 工具
  tool,

  /// 系统
  system;

  /// 获取中文显示标签
  String get label {
    return switch (this) {
      AiChatMessageRole.user => '用户',
      AiChatMessageRole.assistant => '助手',
      AiChatMessageRole.tool => '工具',
      AiChatMessageRole.system => '系统',
    };
  }

  /// 从 API 字符串值转换为枚举
  static AiChatMessageRole fromApi(String? value) {
    return switch (value?.toUpperCase()) {
      'ASSISTANT' => AiChatMessageRole.assistant,
      'TOOL' => AiChatMessageRole.tool,
      'SYSTEM' => AiChatMessageRole.system,
      _ => AiChatMessageRole.user,
    };
  }
}
