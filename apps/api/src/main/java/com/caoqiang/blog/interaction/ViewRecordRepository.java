package com.caoqiang.blog.interaction;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ViewRecordRepository extends JpaRepository<ViewRecord, UUID> {

    Page<ViewRecord> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    Optional<ViewRecord> findByIdAndUserId(UUID id, UUID userId);
}
