package com.caoqiang.blog.audit.application.api;

import com.caoqiang.blog.audit.application.service.AuditLogService;
import com.caoqiang.blog.shared.response.PageResponse;
import java.util.UUID;
import org.springframework.stereotype.Service;

/** Public audit-module query API for administration surfaces. */
@Service
public class AuditAccessService {

    private final AuditLogService auditLogService;

    public AuditAccessService(AuditLogService auditLogService) {
        this.auditLogService = auditLogService;
    }

    public PageResponse<AuditLogView> list(
            int page,
            int size,
            String action,
            String resourceType,
            UUID actorUserId
    ) {
        var result = auditLogService.list(page, size, action, resourceType, actorUserId);
        return new PageResponse<>(
                result.items().stream().map(item -> new AuditLogView(
                        item.id(),
                        item.actorUserId(),
                        item.actorNickname(),
                        item.action(),
                        item.resourceType(),
                        item.resourceId(),
                        item.detail(),
                        item.createdAt()
                )).toList(),
                result.page(),
                result.size(),
                result.total()
        );
    }
}
