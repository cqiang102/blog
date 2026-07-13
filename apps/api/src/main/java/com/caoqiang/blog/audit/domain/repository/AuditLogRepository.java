package com.caoqiang.blog.audit.domain.repository;

import com.caoqiang.blog.audit.domain.model.AuditLog;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

/**
 * 审计日志数据访问层
 * <p>
 * 继承 {@link JpaRepository} 提供基本 CRUD 操作，
 * 继承 {@link JpaSpecificationExecutor} 支持动态查询条件。
 * <p>
 * 使用 {@code @EntityGraph} 优化关联查询，避免 N+1 问题。
 */
public interface AuditLogRepository extends JpaRepository<AuditLog, UUID>, JpaSpecificationExecutor<AuditLog> {

    /**
     * 按创建时间倒序查询所有审计日志（分页）
     * <p>
     * 使用 EntityGraph 预加载 actor 关联，避免 N+1 查询。
     *
     * @param pageable 分页参数
     * @return 审计日志分页结果
     */
    Page<AuditLog> findAllByOrderByCreatedAtDesc(Pageable pageable);

    /**
     * 根据动态条件查询审计日志（分页）
     * <p>
     * 使用 EntityGraph 预加载 actor 关联，避免 N+1 查询。
     *
     * @param spec     动态查询条件
     * @param pageable 分页参数
     * @return 审计日志分页结果
     */
    @Override
    Page<AuditLog> findAll(org.springframework.data.jpa.domain.Specification<AuditLog> spec, Pageable pageable);
}
