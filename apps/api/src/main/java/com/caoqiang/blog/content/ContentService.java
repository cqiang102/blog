package com.caoqiang.blog.content;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.common.BusinessException;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.interaction.LikeRepository;
import jakarta.persistence.criteria.Join;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Predicate;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class ContentService {

    private static final int MAX_PAGE_SIZE = 50;

    private final ContentRepository contentRepository;
    private final LikeRepository likeRepository;

    public ContentService(ContentRepository contentRepository, LikeRepository likeRepository) {
        this.contentRepository = contentRepository;
        this.likeRepository = likeRepository;
    }

    @Transactional(readOnly = true)
    @Cacheable(value = "recommendations", key = "'all'")
    public RecommendationResponse recommendations() {
        return new RecommendationResponse(
                contentRepository.findTop10ByStatusAndPinnedTrueAndPublishedAtIsNotNullOrderByPublishedAtDesc(ContentStatus.PUBLISHED)
                        .stream().map(this::toSummary).toList(),
                contentRepository.findTop10ByStatusAndPublishedAtIsNotNullOrderByPublishedAtDesc(ContentStatus.PUBLISHED)
                        .stream().map(this::toSummary).toList(),
                contentRepository.findTop10ByStatusAndPublishedAtIsNotNullOrderByLikeCountDescPublishedAtDesc(ContentStatus.PUBLISHED)
                        .stream().map(this::toSummary).toList()
        );
    }

    @Transactional(readOnly = true)
    public PageResponse<ContentSummaryResponse> list(
            String query,
            List<String> tags,
            ContentType type,
            Instant from,
            Instant to,
            int page,
            int size
    ) {
        int safePage = Math.max(page, 0);
        int safeSize = Math.max(1, Math.min(size, MAX_PAGE_SIZE));
        PageRequest pageRequest = PageRequest.of(
                safePage,
                safeSize,
                Sort.by(Sort.Direction.DESC, "publishedAt").and(Sort.by(Sort.Direction.DESC, "createdAt"))
        );

        Page<Content> result = contentRepository.findAll(
                publishedContentSpec(query, tags, type, from, to),
                pageRequest
        );
        return new PageResponse<>(
                result.getContent().stream().map(this::toSummary).toList(),
                safePage,
                safeSize,
                result.getTotalElements()
        );
    }

    @Transactional(readOnly = true)
    public ContentDetailResponse detail(UUID id, AuthenticatedUser currentUser) {
        Content content = contentRepository.findByIdAndStatus(id, ContentStatus.PUBLISHED)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
        boolean liked = currentUser != null && likeRepository.existsByContentIdAndUserId(id, currentUser.id());

        return new ContentDetailResponse(
                content.getId(),
                content.getTitle(),
                content.getSlug(),
                content.getType(),
                content.getStatus(),
                content.getSummary(),
                content.getBodyMarkdown(),
                coverUrl(content),
                tagNames(content),
                content.getMediaAssets().stream()
                        .sorted(Comparator.comparing(MediaAsset::getCreatedAt))
                        .map(MediaAssetResponse::from)
                        .toList(),
                liked,
                content.getLikeCount(),
                content.getViewCount(),
                content.getCommentCount(),
                content.getPublishedAt()
        );
    }

    private Specification<Content> publishedContentSpec(
            String query,
            List<String> tags,
            ContentType type,
            Instant from,
            Instant to
    ) {
        return (root, criteriaQuery, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(criteriaBuilder.equal(root.get("status"), ContentStatus.PUBLISHED));
            predicates.add(criteriaBuilder.isNotNull(root.get("publishedAt")));

            if (type != null) {
                predicates.add(criteriaBuilder.equal(root.get("type"), type));
            }

            if (from != null) {
                predicates.add(criteriaBuilder.greaterThanOrEqualTo(root.get("publishedAt"), from));
            }

            if (to != null) {
                predicates.add(criteriaBuilder.lessThanOrEqualTo(root.get("publishedAt"), to));
            }

            if (StringUtils.hasText(query)) {
                String keyword = "%" + query.trim().toLowerCase(Locale.ROOT) + "%";
                predicates.add(criteriaBuilder.or(
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("title")), keyword),
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("summary")), keyword),
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("bodyMarkdown")), keyword)
                ));
            }

            List<String> normalizedTags = tags == null ? List.of() : tags.stream()
                    .filter(StringUtils::hasText)
                    .map(tag -> tag.trim().toLowerCase(Locale.ROOT))
                    .toList();
            if (!normalizedTags.isEmpty()) {
                Join<Content, Tag> tagJoin = root.join("tags", JoinType.INNER);
                predicates.add(criteriaBuilder.lower(tagJoin.get("slug")).in(normalizedTags));
                criteriaQuery.distinct(true);
            }

            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
    }

    private ContentSummaryResponse toSummary(Content content) {
        return new ContentSummaryResponse(
                content.getId(),
                content.getTitle(),
                content.getSlug(),
                content.getType(),
                content.getSummary(),
                coverUrl(content),
                content.isPinned(),
                content.getLikeCount(),
                content.getPublishedAt(),
                tagNames(content)
        );
    }

    private List<String> tagNames(Content content) {
        return content.getTags().stream()
                .sorted(Comparator.comparing(Tag::getName))
                .map(Tag::getName)
                .toList();
    }

    private String coverUrl(Content content) {
        if (content.getCoverMedia() != null && StringUtils.hasText(content.getCoverMedia().getPublicUrl())) {
            return content.getCoverMedia().getPublicUrl();
        }

        return content.getMediaAssets().stream()
                .map(MediaAsset::getPublicUrl)
                .filter(StringUtils::hasText)
                .findFirst()
                .orElse(null);
    }
}
