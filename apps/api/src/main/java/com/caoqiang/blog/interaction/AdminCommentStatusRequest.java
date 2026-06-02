package com.caoqiang.blog.interaction;

import jakarta.validation.constraints.NotNull;

public record AdminCommentStatusRequest(@NotNull CommentStatus status) {
}
