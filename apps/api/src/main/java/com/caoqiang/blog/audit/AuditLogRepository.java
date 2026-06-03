package com.caoqiang.blog.audit;

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
}
