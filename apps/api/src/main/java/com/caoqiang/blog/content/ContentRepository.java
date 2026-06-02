package com.caoqiang.blog.content;

import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.EntityGraph;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

public interface ContentRepository extends JpaRepository<Content, UUID>, JpaSpecificationExecutor<Content> {

    @EntityGraph(attributePaths = {"tags", "coverMedia"})
    List<Content> findTop10ByStatusAndPublishedAtIsNotNullOrderByPublishedAtDesc(ContentStatus status);

    @EntityGraph(attributePaths = {"tags", "coverMedia"})
    List<Content> findTop10ByStatusAndPublishedAtIsNotNullOrderByLikeCountDescPublishedAtDesc(ContentStatus status);

    @EntityGraph(attributePaths = {"tags", "coverMedia"})
    List<Content> findTop10ByStatusAndPinnedTrueAndPublishedAtIsNotNullOrderByPublishedAtDesc(ContentStatus status);

    @EntityGraph(attributePaths = {"tags", "coverMedia", "mediaAssets"})
    Optional<Content> findByIdAndStatus(UUID id, ContentStatus status);

    @Override
    @EntityGraph(attributePaths = {"tags", "coverMedia"})
    Optional<Content> findById(UUID id);

    boolean existsBySlug(String slug);

    boolean existsBySlugAndIdNot(String slug, UUID id);

    boolean existsByIdAndStatus(UUID id, ContentStatus status);

    @Modifying
    @Query("update Content c set c.likeCount = greatest(c.likeCount + :delta, 0) where c.id = :contentId")
    int incrementLikeCount(@Param("contentId") UUID contentId, @Param("delta") long delta);

    @Modifying
    @Query("update Content c set c.viewCount = greatest(c.viewCount + :delta, 0) where c.id = :contentId")
    int incrementViewCount(@Param("contentId") UUID contentId, @Param("delta") long delta);

    @Modifying
    @Query("update Content c set c.commentCount = greatest(c.commentCount + :delta, 0) where c.id = :contentId")
    int incrementCommentCount(@Param("contentId") UUID contentId, @Param("delta") long delta);
}
