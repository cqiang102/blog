package com.caoqiang.blog.audit;

import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.user.User;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuditLogService {

    private static final int MAX_PAGE_SIZE = 100;

    private final AuditLogRepository auditLogRepository;

    public AuditLogService(AuditLogRepository auditLogRepository) {
        this.auditLogRepository = auditLogRepository;
    }

    @Transactional
    public void log(User actor, String action, String resourceType, UUID resourceId, Map<String, Object> detail) {
        AuditLog auditLog = new AuditLog(actor, action, resourceType, resourceId, detail);
        auditLogRepository.save(auditLog);
    }

    @Transactional
    public void log(User actor, String action, String resourceType, UUID resourceId) {
        log(actor, action, resourceType, resourceId, null);
    }

    @Transactional(readOnly = true)
    public PageResponse<AuditLogResponse> list(int page, int size, String action, String resourceType, UUID actorUserId) {
        Page<AuditLog> result = auditLogRepository.findAll(
                filters(action, resourceType, actorUserId),
                PageRequest.of(
                        Math.max(0, page),
                        Math.max(1, Math.min(size, MAX_PAGE_SIZE)),
                        Sort.by(Sort.Direction.DESC, "createdAt")
                )
        );
        return new PageResponse<>(
                result.getContent().stream().map(AuditLogResponse::from).toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    private Specification<AuditLog> filters(String action, String resourceType, UUID actorUserId) {
        return (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (action != null && !action.isBlank()) {
                predicates.add(criteriaBuilder.like(
                        criteriaBuilder.lower(root.get("action")),
                        "%" + action.toLowerCase() + "%"
                ));
            }
            if (resourceType != null && !resourceType.isBlank()) {
                predicates.add(criteriaBuilder.equal(root.get("resourceType"), resourceType));
            }
            if (actorUserId != null) {
                predicates.add(criteriaBuilder.equal(root.get("actor").get("id"), actorUserId));
            }
            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
    }
}
