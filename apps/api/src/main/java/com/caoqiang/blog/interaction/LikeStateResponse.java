package com.caoqiang.blog.interaction;

import java.util.UUID;

public record LikeStateResponse(UUID contentId, boolean liked, long likeCount) {
}
