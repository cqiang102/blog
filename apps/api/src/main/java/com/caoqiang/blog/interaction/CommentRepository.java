package com.caoqiang.blog.interaction;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.domain.Specification;

public interface CommentRepository extends JpaRepository<Comment, UUID>, JpaSpecificationExecutor<Comment> {

    @Override
    @EntityGraph(attributePaths = {"content", "user"})
    Page<Comment> findAll(Specification<Comment> specification, Pageable pageable);

    @Override
    @EntityGraph(attributePaths = {"content", "user"})
    Optional<Comment> findById(UUID id);

    Page<Comment> findByContentIdAndStatusOrderByCreatedAtDesc(UUID contentId, CommentStatus status, Pageable pageable);

    Page<Comment> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);

    Optional<Comment> findByIdAndUserId(UUID id, UUID userId);
}
