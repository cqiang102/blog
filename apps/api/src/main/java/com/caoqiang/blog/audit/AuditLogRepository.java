package com.caoqiang.blog.audit;

import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

/**
 * 审计日志数据访问层
 * <p>
 * 继承 {@link JpaRepository} 提供基本 CRUD 操作，
 * 继承 {@link JpaSpecificationExecutor} 支持动态查询条件。
 * <p>
 * 提供按创建时间降序排列的查询方法，用于审计日志列表展示。
 */
public interface AuditLogRepository extends JpaRepository<AuditLog, UUID>, JpaSpecificationExecutor<AuditLog> {

    /**
     * 查询所有审计日志（按创建时间降序）
     *
     * @param pageable 分页参数
     * @return 审计日志分页结果
     */
    Page<AuditLog> findAllByOrderByCreatedAtDesc(Pageable pageable);

    /**
     * 使用 Specification 查询审计日志，并通过 EntityGraph 预加载 actor 关联
     * <p>
     * 避免 LAZY 加载导致的 N+1 查询问题，同时避免 root.fetch 与 count 查询冲突。
     *
     * @param spec     查询条件
     * @param pageable 分页参数
     * @return 审计日志分页结果
     */
    @EntityGraph(attributePaths = {"actor"})
    @Override
    Page<AuditLog> findAll(org.springframework.data.jpa.domain.Specification<AuditLog> spec, Pageable pageable);
}
