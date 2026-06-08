package com.caoqiang.blog.ai.knowledge.entity;

/**
 * 知识文档来源类型枚举。
 * <p>
 * 定义知识文档的数据来源，对应 {@link KnowledgeDoc#sourceType} 字段。
 */
public enum KnowledgeSourceType {
    /** 手动输入 */
    MANUAL,
    /** 从 URL 抓取 */
    URL,
    /** 文件上传 */
    FILE,
    /** 从博客内容导入 */
    CONTENT
}
