package com.caoqiang.blog.audit.domain.model;

import com.caoqiang.blog.shared.persistence.PgJsonbType;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.PrePersist;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.Map;
import java.util.UUID;
import org.hibernate.annotations.Type;

/**
 * 审计日志实体
 * <p>
 * 对应数据库 {@code audit_logs} 表，记录管理端的所有操作。
 * <p>
 * 主要职责：
 * <ul>
 *   <li>记录操作者（用户）</li>
 *   <li>记录操作类型（CREATE/UPDATE/DELETE/READ）</li>
 *   <li>记录资源类型和资源 ID</li>
 *   <li>记录操作详情（JSON 格式）</li>
 *   <li>记录操作时间</li>
 * </ul>
 * <p>
 * 使用 UUID 作为主键，操作者通过外键关联用户表。
 * 详情字段使用 JSONB 类型存储，便于查询和分析。
 */
@Entity
@Table(name = "audit_logs")
public class AuditLog {

    /** 审计日志唯一标识，UUID 格式 */
    @Id
    @Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 操作者用户 ID；用户删除后由数据库置空 */
    @Column(name = "actor_user_id")
    private UUID actorUserId;

    /** 操作类型（CREATE/UPDATE/DELETE/READ） */
    @Column(nullable = false, length = 120)
    private String action;

    /** 资源类型（CONTENT/USER/FRIEND 等） */
    @Column(name = "resource_type", length = 80)
    private String resourceType;

    /** 资源 ID */
    @Column(name = "resource_id")
    private UUID resourceId;

    /** 操作详情，JSON 格式 */
    @Column(columnDefinition = "JSONB")
    @Type(PgJsonbType.class)
    private String detail;

    /** 创建时间，不可更新 */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** JPA 保护构造函数 */
    protected AuditLog() {}

    /**
     * 创建审计日志
     *
     * @param actorUserId  操作者用户 ID
     * @param action       操作类型
     * @param resourceType 资源类型
     * @param resourceId   资源 ID
     * @param detail       操作详情，可为 null
     */
    public AuditLog(UUID actorUserId, String action, String resourceType, UUID resourceId, Map<String, Object> detail) {
        this.actorUserId = actorUserId;
        this.action = action;
        this.resourceType = resourceType;
        this.resourceId = resourceId;
        // 将详情 Map 转换为 JSON 字符串
        if (detail != null && !detail.isEmpty()) {
            this.detail = mapToJson(detail);
        }
    }

    /**
     * 实体持久化前的回调，自动设置创建时间
     */
    @PrePersist
    void onCreate() {
        if (createdAt == null) {
            createdAt = Instant.now();
        }
    }

    public UUID getId() {
        return id;
    }

    public UUID getActorUserId() {
        return actorUserId;
    }

    public String getAction() {
        return action;
    }

    public String getResourceType() {
        return resourceType;
    }

    public UUID getResourceId() {
        return resourceId;
    }

    public String getDetail() {
        return detail;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    /**
     * 将 Map 转换为 JSON 字符串
     * <p>
     * 手动构建 JSON，避免引入额外的 JSON 库依赖。
     * 支持 null、String、Number、Boolean 类型。
     *
     * @param map 要转换的 Map
     * @return JSON 字符串
     */
    private String mapToJson(Map<String, Object> map) {
        StringBuilder sb = new StringBuilder("{");
        boolean first = true;
        for (Map.Entry<String, Object> entry : map.entrySet()) {
            if (!first) sb.append(",");
            sb.append("\"").append(entry.getKey()).append("\":");
            Object value = entry.getValue();
            if (value == null) {
                sb.append("null");
            } else if (value instanceof String) {
                sb.append("\"").append(((String) value).replace("\"", "\\\"")).append("\"");
            } else if (value instanceof Number || value instanceof Boolean) {
                sb.append(value);
            } else {
                sb.append("\"").append(value.toString().replace("\"", "\\\"")).append("\"");
            }
            first = false;
        }
        sb.append("}");
        return sb.toString();
    }
}
