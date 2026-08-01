package com.caoqiang.blog.audit.application.service;

import com.caoqiang.blog.audit.application.dto.AuditLogResponse;
import com.caoqiang.blog.audit.domain.model.AuditLog;
import com.caoqiang.blog.audit.domain.repository.AuditLogRepository;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.shared.util.PageUtils;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 审计日志服务
 * <p>
 * 处理审计日志的业务逻辑，包括：
 * <ul>
 *   <li>记录审计日志（支持带详情和不带详情两种方式）</li>
 *   <li>查询审计日志列表（支持按操作类型、资源类型、操作者筛选）</li>
 * </ul>
 * <p>
 * 审计日志用于追踪管理端的所有操作，便于安全审计和问题排查。
 */
@Service
public class AuditLogService {

    /** 最大分页大小限制 */
    private static final int MAX_PAGE_SIZE = 100;

    /** 审计日志数据访问层 */
    private final AuditLogRepository auditLogRepository;

    private final UserAccountService userAccountService;

    public AuditLogService(AuditLogRepository auditLogRepository, UserAccountService userAccountService) {
        this.auditLogRepository = auditLogRepository;
        this.userAccountService = userAccountService;
    }

    /**
     * 记录审计日志（带详情）
     *
     * @param actorUserId        操作者用户实体
     * @param action       操作类型（CREATE/UPDATE/DELETE/READ）
     * @param resourceType 资源类型（CONTENT/USER/FRIEND 等）
     * @param resourceId   资源 ID
     * @param detail       操作详情，可选
     */
    @Transactional
    public void log(UUID actorUserId, String action, String resourceType, UUID resourceId, Map<String, Object> detail) {
        AuditLog auditLog = new AuditLog(actorUserId, action, resourceType, resourceId, detail);
        auditLogRepository.save(auditLog);
    }

    /**
     * 记录审计日志（不带详情）
     *
     * @param actorUserId        操作者用户实体
     * @param action       操作类型（CREATE/UPDATE/DELETE/READ）
     * @param resourceType 资源类型（CONTENT/USER/FRIEND 等）
     * @param resourceId   资源 ID
     */
    @Transactional
    public void log(UUID actorUserId, String action, String resourceType, UUID resourceId) {
        log(actorUserId, action, resourceType, resourceId, null);
    }

    /**
     * 获取审计日志列表（分页、筛选）
     *
     * @param page         页码，从 0 开始
     * @param size         每页大小，最大 100
     * @param action       操作类型筛选条件
     * @param resourceType 资源类型筛选条件
     * @param actorUserId  操作者用户 ID 筛选条件
     * @return 审计日志分页响应
     */
    @Transactional(readOnly = true)
    public PageResponse<AuditLogResponse> list(
            int page, int size, String action, String resourceType, UUID actorUserId) {
        Page<AuditLog> result = auditLogRepository.findAll(
                filters(action, resourceType, actorUserId),
                PageUtils.of(page, size, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "createdAt")));
        Map<UUID, IdentityUser> actors = userAccountService
                .findByIds(result.getContent().stream()
                        .map(AuditLog::getActorUserId)
                        .filter(java.util.Objects::nonNull)
                        .distinct()
                        .toList())
                .stream()
                .collect(java.util.stream.Collectors.toMap(
                        IdentityUser::id, java.util.function.Function.identity(), (a, b) -> a));
        return new PageResponse<>(
                result.getContent().stream()
                        .map(log -> AuditLogResponse.from(log, actors.get(log.getActorUserId())))
                        .toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements());
    }

    /**
     * 构建审计日志查询条件
     * <p>
     * 支持按操作类型、资源类型、操作者用户 ID 进行筛选。
     *
     * @param action       操作类型筛选条件
     * @param resourceType 资源类型筛选条件
     * @param actorUserId  操作者用户 ID 筛选条件
     * @return JPA Specification 查询条件
     */
    private Specification<AuditLog> filters(String action, String resourceType, UUID actorUserId) {
        return (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            // 操作类型模糊匹配
            if (action != null && !action.isBlank()) {
                predicates.add(criteriaBuilder.like(
                        criteriaBuilder.lower(root.get("action")), "%" + action.toLowerCase() + "%"));
            }
            // 资源类型精确匹配
            if (resourceType != null && !resourceType.isBlank()) {
                predicates.add(criteriaBuilder.equal(root.get("resourceType"), resourceType));
            }
            // 操作者用户 ID 精确匹配
            if (actorUserId != null) {
                predicates.add(criteriaBuilder.equal(root.get("actorUserId"), actorUserId));
            }
            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
    }
}
