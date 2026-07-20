package com.caoqiang.blog.interaction.application.api;

import com.caoqiang.blog.interaction.domain.model.ActivityType;
import java.time.Instant;
import java.util.UUID;

public record UserActivityItem(UUID id, ActivityType type, UUID contentId, String title, Instant createdAt) {}
