package com.caoqiang.blog.friend;

import java.time.Instant;
import java.util.UUID;

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

    public static FriendResponse from(Friend friend) {
        return new FriendResponse(
                friend.getId(),
                friend.getName(),
                friend.getIntro(),
                friend.getAvatarUrl(),
                friend.getSiteUrl(),
                friend.isVisible(),
                friend.getSortOrder(),
                friend.getCreatedAt(),
                friend.getUpdatedAt()
        );
    }
}
