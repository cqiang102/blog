package com.caoqiang.blog.interaction;

/**
 * 评论状态枚举
 * <p>
 * 定义评论的生命周期状态。位于领域模型层，用于控制评论的可见性和审核流程。
 * </p>
 * <p>
 * 状态说明：
 * <ul>
 *   <li>{@link #VISIBLE} - 可见状态，评论正常显示</li>
 *   <li>{@link #PENDING} - 待审核状态，新创建的评论默认状态</li>
 *   <li>{@link #BLOCKED} - 被屏蔽状态，AI 审核不通过或管理员手动屏蔽</li>
 *   <li>{@link #DELETED} - 已删除状态，软删除标记</li>
 * </ul>
 * </p>
 */
public enum CommentStatus {
    /** 可见状态，评论正常显示 */
    VISIBLE,
    /** 待审核状态，新创建的评论默认状态 */
    PENDING,
    /** 被屏蔽状态，AI 审核不通过或管理员手动屏蔽 */
    BLOCKED,
    /** 已删除状态，软删除标记 */
    DELETED
}
