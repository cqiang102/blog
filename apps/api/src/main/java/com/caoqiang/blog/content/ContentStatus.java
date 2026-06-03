package com.caoqiang.blog.content;

/**
 * 内容状态枚举。
 * <p>
 * 定义内容的生命周期状态，控制内容的可见性和行为：
 * <ul>
 *   <li>{@link #DRAFT} - 草稿：仅管理端可见，不参与公开查询和推荐</li>
 *   <li>{@link #PUBLISHED} - 已发布：公开可见，参与搜索、推荐、知识库索引</li>
 *   <li>{@link #ARCHIVED} - 已归档：不再公开展示，向量索引被清除</li>
 * </ul>
 */
public enum ContentStatus {

    /** 草稿状态 */
    DRAFT,

    /** 已发布状态 */
    PUBLISHED,

    /** 已归档状态 */
    ARCHIVED
}
