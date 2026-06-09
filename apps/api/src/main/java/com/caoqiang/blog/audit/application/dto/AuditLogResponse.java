package com.caoqiang.blog.audit.application.dto;

import com.caoqiang.blog.audit.domain.model.AuditLog;

import java.time.Instant;
import java.util.UUID;

/**
 * 审计日志响应 DTO
 * <p>
 * 用于返回审计日志信息，包含操作者信息和操作详情。
 * <p>
 * 将操作者用户信息（ID 和昵称）平铺到响应中，
 * 避免返回完整的用户对象，简化前端处理。
 *
 * @param id            审计日志 ID
 * @param actorUserId   操作者用户 ID
 * @param actorNickname 操作者用户昵称
 * @param action        操作类型（CREATE/UPDATE/DELETE/READ）
 * @param resourceType  资源类型（CONTENT/USER/FRIEND 等）
 * @param resourceId    资源 ID
 * @param detail        操作详情，JSON 字符串
 * @param createdAt     创建时间
 */
public record AuditLogResponse(
        UUID id,
        UUID actorUserId,
        String actorNickname,
        String action,
        String resourceType,
        UUID resourceId,
        String detail,
        Instant createdAt
) {

    /**
     * 从审计日志实体创建响应 DTO
     * <p>
     * 安全处理操作者可能为空的情况。
     *
     * @param log 审计日志实体
     * @return 审计日志响应 DTO
     */
    public static AuditLogResponse from(AuditLog log) {
        return new AuditLogResponse(
                log.getId(),
                log.getActor() != null ? log.getActor().getId() : null,
                log.getActor() != null ? log.getActor().getNickname() : null,
                log.getAction(),
                log.getResourceType(),
                log.getResourceId(),
                log.getDetail(),
                log.getCreatedAt()
        );
    }
}
