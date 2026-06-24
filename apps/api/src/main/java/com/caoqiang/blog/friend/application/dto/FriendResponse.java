package com.caoqiang.blog.friend.application.dto;

import com.caoqiang.blog.friend.domain.model.Friend;

import java.time.Instant;
import java.util.UUID;
import java.util.function.Function;

/**
 * 友链响应 DTO
 * <p>
 * 用于返回友链信息，包含友链的完整信息。
 * <p>
 * 同时用于前台展示和后台管理，包含友链的基本信息、
 * 可见性状态、排序权重和时间戳。
 *
 * @param id        友链 ID
 * @param name      友链名称
 * @param intro     友链简介
 * @param avatarUrl 友链头像 URL
 * @param siteUrl   友链网站 URL
 * @param visible   是否可见
 * @param sortOrder 排序权重
 * @param createdAt 创建时间
 * @param updatedAt 最后更新时间
 */
public record FriendResponse(
        UUID id,
        String name,
        String intro,
        String avatarUrl,
        String siteUrl,
        boolean visible,
        int sortOrder,
        Instant createdAt,
        Instant updatedAt
) {

    /**
     * 从友链实体创建响应 DTO
     *
     * @param friend 友链实体
     * @return 友链响应 DTO
     */
    public static FriendResponse from(Friend friend) {
        return from(friend, Function.identity());
    }

    public static FriendResponse from(Friend friend, Function<String, String> avatarUrlResolver) {
        return new FriendResponse(
                friend.getId(),
                friend.getName(),
                friend.getIntro(),
                avatarUrlResolver.apply(friend.getAvatarUrl()),
                friend.getSiteUrl(),
                friend.isVisible(),
                friend.getSortOrder(),
                friend.getCreatedAt(),
                friend.getUpdatedAt()
        );
    }
}
