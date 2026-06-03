package com.caoqiang.blog.interaction;

import jakarta.validation.constraints.NotNull;

/**
 * 管理端评论状态请求 DTO（数据传输对象）
 * <p>
 * 用于接收管理员修改评论状态的请求。位于 API 层，使用 Java Record 实现不可变数据结构。
 * </p>
 * <p>
 * 验证规则：
 * <ul>
 *   <li>status 不能为 null</li>
 * </ul>
 * </p>
 *
 * @param status 目标评论状态，不能为 null
 */
public record AdminCommentStatusRequest(@NotNull CommentStatus status) {
}
