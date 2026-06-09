package com.caoqiang.blog.interaction.domain.model;

/**
 * 用户活动类型枚举
 * <p>
 * 定义用户互动活动的类型。位于领域模型层，用于标准化用户活动记录中的类型字段。
 * </p>
 * <p>
 * 活动类型说明：
 * <ul>
 *   <li>{@link #COMMENT} - 评论活动</li>
 *   <li>{@link #LIKE} - 点赞活动</li>
 *   <li>{@link #VIEW} - 浏览活动</li>
 * </ul>
 * </p>
 */
public enum ActivityType {
    /** 评论活动 */
    COMMENT,
    /** 点赞活动 */
    LIKE,
    /** 浏览活动 */
    VIEW
}
