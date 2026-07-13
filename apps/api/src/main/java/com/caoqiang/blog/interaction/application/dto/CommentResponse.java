package com.caoqiang.blog.interaction.application.dto;

import com.caoqiang.blog.content.application.api.ContentInteractionSnapshot;
import com.caoqiang.blog.interaction.domain.model.Comment;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import com.caoqiang.blog.user.application.api.IdentityUser;

import java.time.Instant;
import java.util.UUID;

/**
 * 评论响应 DTO（数据传输对象）
 * <p>
 * 用于向前端返回评论数据。位于 API 层，使用 Java Record 实现不可变数据结构。
 * </p>
 * <p>
 * 包含评论的基本信息、关联内容信息、作者信息和审核状态。
 * </p>
 *
 * @param id           评论 ID
 * @param contentId    关联内容 ID
 * @param contentTitle 关联内容标题
 * @param body         评论内容
 * @param author       评论作者信息
 * @param auditStatus  AI 审核状态
 * @param createdAt    创建时间
 */
public record CommentResponse(
        UUID id,
        UUID contentId,
        String contentTitle,
        String body,
        CommentAuthor author,
        CommentStatus auditStatus,
        Instant createdAt
) {

    /**
     * 从评论实体创建响应 DTO
     *
     * @param comment 评论实体
     * @return 评论响应 DTO
     */
    public static CommentResponse from(
            Comment comment,
            ContentInteractionSnapshot content,
            IdentityUser author,
            String presignedAvatarUrl
    ) {
        return new CommentResponse(
                comment.getId(),
                comment.getContentId(),
                content.title(),
                comment.getBody(),
                new CommentAuthor(
                        comment.getUserId(),
                        author.nickname(),
                        presignedAvatarUrl
                ),
                comment.getAuditStatus(),
                comment.getCreatedAt()
        );
    }

    /**
     * 评论作者信息
     *
     * @param id        用户 ID
     * @param nickname  用户昵称
     * @param avatarUrl 用户头像 URL
     */
    public record CommentAuthor(UUID id, String nickname, String avatarUrl) {
    }
}
