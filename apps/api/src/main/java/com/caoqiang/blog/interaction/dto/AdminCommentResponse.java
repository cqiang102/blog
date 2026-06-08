package com.caoqiang.blog.interaction.dto;

import com.caoqiang.blog.interaction.entity.Comment;
import com.caoqiang.blog.interaction.entity.CommentStatus;
import com.caoqiang.blog.interaction.entity.Like;
import com.caoqiang.blog.interaction.entity.ViewRecord;

import java.time.Instant;
import java.util.UUID;

/**
 * 管理端评论响应 DTO（数据传输对象）
 * <p>
 * 用于向前端管理界面返回评论数据。位于 API 层，使用 Java Record 实现不可变数据结构。
 * </p>
 * <p>
 * 相比普通评论响应，包含更多管理所需信息：
 * <ul>
 *   <li>用户 ID、昵称、邮箱</li>
 *   <li>评论状态</li>
 *   <li>创建和更新时间</li>
 * </ul>
 * </p>
 *
 * @param id           评论 ID
 * @param contentId    关联内容 ID
 * @param contentTitle 关联内容标题
 * @param userId       评论作者 ID
 * @param userNickname 评论作者昵称
 * @param userEmail    评论作者邮箱
 * @param status       评论状态
 * @param body         评论内容
 * @param createdAt    创建时间
 * @param updatedAt    更新时间
 */
public record AdminCommentResponse(
        UUID id,
        UUID contentId,
        String contentTitle,
        UUID userId,
        String userNickname,
        String userEmail,
        CommentStatus status,
        String body,
        Instant createdAt,
        Instant updatedAt
) {

    /**
     * 从评论实体创建管理端响应 DTO
     *
     * @param comment 评论实体
     * @return 管理端评论响应 DTO
     */
    public static AdminCommentResponse from(Comment comment) {
        return new AdminCommentResponse(
                comment.getId(),
                comment.getContent().getId(),
                comment.getContent().getTitle(),
                comment.getUser().getId(),
                comment.getUser().getNickname(),
                comment.getUser().getEmail(),
                comment.getStatus(),
                comment.getBody(),
                comment.getCreatedAt(),
                comment.getUpdatedAt()
        );
    }
}
