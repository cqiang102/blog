package com.caoqiang.blog.interaction;

import java.time.Instant;
import java.util.UUID;

/**
 * 管理端点赞响应 DTO（数据传输对象）
 * <p>
 * 用于向前端管理界面返回点赞记录数据。位于 API 层，使用 Java Record 实现不可变数据结构。
 * </p>
 * <p>
 * 包含点赞记录的详细信息，包括关联内容和用户信息。
 * </p>
 *
 * @param id           点赞记录 ID
 * @param contentId    关联内容 ID
 * @param contentTitle 关联内容标题
 * @param userId       点赞用户 ID
 * @param userNickname 点赞用户昵称
 * @param userEmail    点赞用户邮箱
 * @param createdAt    创建时间
 */
public record AdminLikeResponse(
        UUID id,
        UUID contentId,
        String contentTitle,
        UUID userId,
        String userNickname,
        String userEmail,
        Instant createdAt
) {

    /**
     * 从点赞实体创建管理端响应 DTO
     *
     * @param like 点赞实体
     * @return 管理端点赞响应 DTO
     */
    public static AdminLikeResponse from(Like like) {
        return new AdminLikeResponse(
                like.getId(),
                like.getContent().getId(),
                like.getContent().getTitle(),
                like.getUser().getId(),
                like.getUser().getNickname(),
                like.getUser().getEmail(),
                like.getCreatedAt()
        );
    }
}
