package com.caoqiang.blog.content.application.api;

import java.util.UUID;

public record ContentAccessDetail(
        UUID id,
        String title,
        String summary,
        String bodyMarkdown,
        String type,
        long likeCount,
        long viewCount,
        long commentCount) {}
