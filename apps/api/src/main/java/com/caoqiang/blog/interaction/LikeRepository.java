package com.caoqiang.blog.interaction;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface LikeRepository extends JpaRepository<Like, UUID> {

    boolean existsByContentIdAndUserId(UUID contentId, UUID userId);

    Optional<Like> findByContentIdAndUserId(UUID contentId, UUID userId);

    Page<Like> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);
}
