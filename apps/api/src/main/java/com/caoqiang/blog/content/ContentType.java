package com.caoqiang.blog.content;

/**
 * 内容类型枚举。
 * <p>
 * 定义博客系统支持的内容类型，用于内容分类和前端展示差异化处理。
 * 存储在数据库中以字符串形式持久化。
 */
public enum ContentType {

    /** 文章（Markdown 格式，支持富文本渲染） */
    ARTICLE,

    /** 图片内容 */
    IMAGE,

    /** 视频内容 */
    VIDEO
}
