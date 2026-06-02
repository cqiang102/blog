package com.caoqiang.blog.interaction;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.domain.Specification;

public interface ViewRecordRepository extends JpaRepository<ViewRecord, UUID>, JpaSpecificationExecutor<ViewRecord> {

    @Override
    @EntityGraph(attributePaths = {"content", "user"})
    Page<ViewRecord> findAll(Specification<ViewRecord> specification, Pageable pageable);

    @Override
    @EntityGraph(attributePaths = {"content", "user"})
    Optional<ViewRecord> findById(UUID id);

    Page<ViewRecord> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    Optional<ViewRecord> findByIdAndUserId(UUID id, UUID userId);

    boolean existsByContentIdAndAnonymousId(UUID contentId, String anonymousId);

    boolean existsByContentIdAndUserId(UUID contentId, UUID userId);
}
