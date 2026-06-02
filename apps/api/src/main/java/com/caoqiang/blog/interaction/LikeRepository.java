package com.caoqiang.blog.interaction;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.domain.Specification;

public interface LikeRepository extends JpaRepository<Like, UUID>, JpaSpecificationExecutor<Like> {

    @Override
    @EntityGraph(attributePaths = {"content", "user"})
    Page<Like> findAll(Specification<Like> specification, Pageable pageable);

    @Override
    @EntityGraph(attributePaths = {"content", "user"})
    Optional<Like> findById(UUID id);

    boolean existsByContentIdAndUserId(UUID contentId, UUID userId);

    Optional<Like> findByContentIdAndUserId(UUID contentId, UUID userId);

    Page<Like> findByUserIdOrderByCreatedAtDesc(UUID userId, Pageable pageable);
}
