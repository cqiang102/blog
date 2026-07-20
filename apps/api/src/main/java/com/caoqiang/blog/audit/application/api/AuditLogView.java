package com.caoqiang.blog.audit.application.api;

import java.time.Instant;
import java.util.UUID;

public record AuditLogView(
        UUID id,
        UUID actorUserId,
        String actorNickname,
        String action,
        String resourceType,
        UUID resourceId,
        String detail,
        Instant createdAt) {}
