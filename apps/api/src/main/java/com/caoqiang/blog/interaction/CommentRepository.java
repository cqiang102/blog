package com.caoqiang.blog.interaction;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface CommentRepository extends JpaRepository<Comment, UUID> {

    Page<Comment> findByContentIdAndStatusOrderByCreatedAtDesc(UUID contentId, CommentStatus status, Pageable pageable);

    Page<Comment> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    Optional<Comment> findByIdAndUserId(UUID id, UUID userId);
}
