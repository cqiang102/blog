package com.caoqiang.blog.content;

/**
 * 内容类型枚举。
 * <p>
 * 定义博客系统支持的内容类型，用于内容分类和前端展示差异化处理。
 * 存储在数据库中以字符串形式持久化。
 * <p>
 * 注意：TEXT 和 ARTICLE 在逻辑上等价，都表示 Markdown 内容。
 * 新创建的内容统一使用 ARTICLE 类型。
 */
public enum ContentType {

    /** 纯文本（已废弃，等同于 ARTICLE） */
    @Deprecated("使用 ARTICLE 代替")
    TEXT,

    /** 文章（Markdown 格式，支持富文本渲染） */
    ARTICLE,

    /** 图片内容 */
    IMAGE,

    /** 视频内容 */
    VIDEO;

    /**
     * 判断是否为 Markdown 内容类型（TEXT 或 ARTICLE）
     *
     * @return 如果是 Markdown 类型返回 true
     */
    public boolean isMarkdown() {
        return this == TEXT || this == ARTICLE;
    }
}
