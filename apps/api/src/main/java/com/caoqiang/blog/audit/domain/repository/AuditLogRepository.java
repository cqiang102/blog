package com.caoqiang.blog.audit.domain.repository;

import com.caoqiang.blog.audit.domain.model.AuditLog;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

public interface AuditLogRepository extends JpaRepository<AuditLog, UUID>, JpaSpecificationExecutor<AuditLog> {

    @EntityGraph(attributePaths = {"actor"})
    Page<AuditLog> findAllByOrderByCreatedAtDesc(Pageable pageable);

    @EntityGraph(attributePaths = {"actor"})
    @Override
    Page<AuditLog> findAll(org.springframework.data.jpa.domain.Specification<AuditLog> spec, Pageable pageable);
}
