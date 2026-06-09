package com.caoqiang.blog.interaction.application.dto;

import com.caoqiang.blog.interaction.domain.model.Comment;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import com.caoqiang.blog.interaction.domain.model.Like;
import com.caoqiang.blog.interaction.domain.model.ViewRecord;

import java.util.UUID;

/**
 * 点赞状态响应 DTO（数据传输对象）
 * <p>
 * 用于向前端返回点赞操作的结果。位于 API 层，使用 Java Record 实现不可变数据结构。
 * </p>
 * <p>
 * 包含内容 ID、当前用户的点赞状态和总点赞数。
 * </p>
 *
 * @param contentId  内容 ID
 * @param liked      当前用户是否已点赞
 * @param likeCount  内容的总点赞数
 */
public record LikeStateResponse(UUID contentId, boolean liked, long likeCount) {
}
