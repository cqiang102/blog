package com.caoqiang.blog.friend;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

public record FriendRequest(
        @NotBlank @Size(max = 80) String name,
        String avatarUrl,
        @Size(max = 1000) String intro,
        @NotBlank String siteUrl,
        boolean visible,
        int sortOrder
) {
}
