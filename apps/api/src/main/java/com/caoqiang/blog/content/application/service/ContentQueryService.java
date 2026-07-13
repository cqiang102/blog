package com.caoqiang.blog.content.application.service;

import com.caoqiang.blog.content.application.dto.ContentDetailResponse;
import com.caoqiang.blog.content.application.dto.ContentSummaryResponse;
import com.caoqiang.blog.content.application.dto.MediaAssetResponse;
import com.caoqiang.blog.content.application.dto.RecommendationResponse;
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaReference;
import com.caoqiang.blog.content.domain.model.Tag;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.repository.MediaAssetRepository;

import com.caoqiang.blog.config.CacheNames;
import com.caoqiang.blog.content.infrastructure.web.ContentController;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.interaction.application.api.InteractionStateService;
import jakarta.persistence.criteria.Join;
import jakarta.persistence.criteria.JoinType;
import jakarta.persistence.criteria.Predicate;
import java.time.Instant;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.LinkedHashMap;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * 内容公开查询服务。
 * <p>
 * 位于博客系统的业务服务层，为 {@link ContentController} 提供只读查询能力。
 * 核心职责：
 * <ul>
 *   <li>推荐内容查询（置顶、最新、最热），结果通过 Redis 缓存</li>
 *   <li>内容列表查询，支持关键词模糊搜索、标签过滤、类型过滤、时间范围过滤、分页</li>
 *   <li>内容详情查询，包含当前用户点赞状态</li>
 * </ul>
 * 所有查询均以 JPA Specification 动态构建 WHERE 条件，仅返回已发布状态的内容。
 */
@Service
public class ContentQueryService {

    /** 最大每页条数，防止前端传入过大的 size 导致性能问题 */
    private static final int MAX_PAGE_SIZE = 50;

    private final ContentRepository contentRepository;
    private final MediaAssetRepository mediaAssetRepository;
    private final InteractionStateService interactionStateService;
    private final MediaAdminService mediaAdminService;
    private final CacheManager cacheManager;

    public ContentQueryService(
            ContentRepository contentRepository,
            MediaAssetRepository mediaAssetRepository,
            InteractionStateService interactionStateService,
            MediaAdminService mediaAdminService,
            CacheManager cacheManager
    ) {
        this.contentRepository = contentRepository;
        this.mediaAssetRepository = mediaAssetRepository;
        this.interactionStateService = interactionStateService;
        this.mediaAdminService = mediaAdminService;
        this.cacheManager = cacheManager;
    }

    /**
     * 获取推荐内容，结果缓存在 Redis 中（key = "all"）。
     * <p>
     * 返回三组推荐列表：置顶内容、最新内容、最热内容（按点赞数排序），每组最多 10 条。
     * 注意：预签名 URL 有效期（7 天）大于缓存 TTL（5 分钟），不会出现缓存过期 URL 问题。
     *
     * @return 推荐内容响应
     */
    @Transactional(readOnly = true)
    @Cacheable(value = CacheNames.RECOMMENDATIONS, key = "'all'")
    public RecommendationResponse recommendations() {
        List<Content> pinned = contentRepository
                .findTop10ByStatusAndPinnedTrueAndPublishedAtIsNotNullAndDeletedAtIsNullOrderByPublishedAtDesc(
                        ContentStatus.PUBLISHED);
        List<Content> latest = contentRepository
                .findTop10ByStatusAndPublishedAtIsNotNullAndDeletedAtIsNullOrderByPublishedAtDesc(
                        ContentStatus.PUBLISHED);
        List<Content> mostLiked = contentRepository
                .findTop10ByStatusAndPublishedAtIsNotNullAndDeletedAtIsNullOrderByLikeCountDescPublishedAtDesc(
                        ContentStatus.PUBLISHED);
        return new RecommendationResponse(
                toSummaries(pinned),
                toSummaries(latest),
                toSummaries(mostLiked)
        );
    }

    /**
     * 分页查询已发布内容列表，支持多条件组合过滤。
     *
     * @param query 搜索关键词，模糊匹配标题、摘要、正文（不区分大小写）
     * @param tags  标签 slug 列表，多标签取交集
     * @param type  内容类型过滤
     * @param from  发布时间起始（含）
     * @param to    发布时间截止（含）
     * @param page  页码，从 0 开始
     * @param size  每页条数，上限 {@link #MAX_PAGE_SIZE}
     * @return 分页内容摘要
     */
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
        // 参数安全化：page 不小于 0，size 限制在 [1, MAX_PAGE_SIZE]
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
        List<Content> hydratedContents = hydrateSummaryRelations(result.getContent());
        return new PageResponse<>(
                toSummaries(hydratedContents),
                safePage,
                safeSize,
                result.getTotalElements()
        );
    }

    /**
     * 获取单篇已发布内容的详情，包含正文、媒体资源、点赞状态等。
     * 媒体资源 URL 使用预签名 URL，确保安全性。
     *
     * @param id          内容 UUID
     * @param currentUser 当前登录用户（可为 null，未登录时 likedByCurrentUser 为 false）
     * @return 内容详情响应
     * @throws BusinessException 内容不存在或未发布时抛出 404
     */
    @Transactional(readOnly = true)
    public ContentDetailResponse detail(UUID id, AuthenticatedUser currentUser) {
        boolean isAdmin = currentUser != null && currentUser.role() == Role.ADMIN;
        Content content = isAdmin
                ? contentRepository.findByIdAndDeletedAtIsNull(id)
                        .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"))
                : contentRepository.findByIdAndStatusAndDeletedAtIsNull(id, ContentStatus.PUBLISHED)
                        .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
        // 查询当前用户是否已点赞该内容
        boolean liked = currentUser != null && interactionStateService.isLiked(id, currentUser.id());

        // 获取预签名 URL 列表
        List<MediaAssetResponse> mediaAssets = content.getMediaAssets().stream()
                .sorted(Comparator.comparing(MediaAsset::getCreatedAt))
                .map(media -> {
                    String presignedUrl = mediaAdminService.getPresignedUrl(media.getId());
                    return new MediaAssetResponse(
                            media.getId(),
                            media.getType(),
                            presignedUrl,
                            media.getFilename(),
                            media.getContentType(),
                            media.getByteSize(),
                            media.getWidth(),
                            media.getHeight(),
                            media.getDurationSeconds()
                    );
                })
                .toList();

        // 封面 URL 也使用预签名
        String coverUrl = presignedCoverUrl(content);

        return new ContentDetailResponse(
                content.getId(),
                content.getTitle(),
                content.getSlug(),
                content.getType(),
                content.getStatus(),
                content.getSummary(),
                MediaReference.normalizeMarkdown(
                        content.getBodyMarkdown(),
                        content.getMediaAssets()
                ),
                coverUrl,
                tagNames(content),
                mediaAssets,
                liked,
                content.getLikeCount(),
                content.getViewCount(),
                content.getCommentCount(),
                content.getPublishedAt()
        );
    }

    /**
     * 构建已发布内容的动态查询条件（JPA Specification）。
     * <p>
     * 条件组合逻辑：
     * <ol>
     *   <li>状态必须为 PUBLISHED 且 publishedAt 不为 null</li>
     *   <li>可选：内容类型、发布时间范围</li>
     *   <li>可选：关键词模糊匹配标题/摘要/正文（不区分大小写）</li>
     *   <li>可选：标签 slug 列表过滤（INNER JOIN，多标签取交集）</li>
     * </ol>
     *
     * @param query 搜索关键词
     * @param tags  标签 slug 列表
     * @param type  内容类型
     * @param from  发布时间起始
     * @param to    发布时间截止
     * @return 动态查询条件
     */
    private Specification<Content> publishedContentSpec(
            String query,
            List<String> tags,
            ContentType type,
            Instant from,
            Instant to
    ) {
        return (root, criteriaQuery, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            // 基础条件：已发布、有发布时间、未被逻辑删除
            predicates.add(criteriaBuilder.equal(root.get("status"), ContentStatus.PUBLISHED));
            predicates.add(criteriaBuilder.isNotNull(root.get("publishedAt")));
            predicates.add(criteriaBuilder.isNull(root.get("deletedAt")));

            if (type != null) {
                predicates.add(criteriaBuilder.equal(root.get("type"), type));
            }

            if (from != null) {
                predicates.add(criteriaBuilder.greaterThanOrEqualTo(root.get("publishedAt"), from));
            }

            if (to != null) {
                predicates.add(criteriaBuilder.lessThanOrEqualTo(root.get("publishedAt"), to));
            }

            // 关键词模糊搜索：匹配标题、摘要、正文
            if (StringUtils.hasText(query)) {
                String keyword = "%" + query.trim().toLowerCase(Locale.ROOT) + "%";
                predicates.add(criteriaBuilder.or(
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("title")), keyword),
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("summary")), keyword),
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("bodyMarkdown")), keyword)
                ));
            }

            // 每个标签使用独立 JOIN，确保内容同时拥有全部选中标签。
            List<String> normalizedTags = tags == null ? List.of() : tags.stream()
                    .filter(StringUtils::hasText)
                    .map(tag -> tag.trim().toLowerCase(Locale.ROOT))
                    .distinct()
                    .toList();
            for (String normalizedTag : normalizedTags) {
                Join<Content, Tag> tagJoin = root.join("tags", JoinType.INNER);
                predicates.add(criteriaBuilder.equal(
                        criteriaBuilder.lower(tagJoin.get("slug")),
                        normalizedTag
                ));
                criteriaQuery.distinct(true);
            }

            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
    }

    /**
     * 将 Content 实体转换为列表摘要 DTO。
     *
     * @param content 内容实体
     * @return 内容摘要响应
     */
    private ContentSummaryResponse toSummary(Content content, MediaAsset fallbackCover) {
        return new ContentSummaryResponse(
                content.getId(),
                content.getTitle(),
                content.getSlug(),
                content.getType(),
                content.getStatus(),
                content.getSummary(),
                presignedCoverUrl(content, fallbackCover),
                content.isPinned(),
                content.getLikeCount(),
                content.getPublishedAt(),
                tagNames(content)
        );
    }

    /**
     * 保持数据库分页顺序，用一条固定查询批量加载 tags 与显式封面。
     */
    private List<Content> hydrateSummaryRelations(List<Content> contents) {
        if (contents.isEmpty()) {
            return List.of();
        }
        List<UUID> ids = contents.stream().map(Content::getId).toList();
        Map<UUID, Content> hydratedById = contentRepository
                .findAllWithSummaryRelationsByIdIn(ids)
                .stream()
                .collect(java.util.stream.Collectors.toMap(Content::getId, content -> content));
        return contents.stream()
                .map(content -> hydratedById.getOrDefault(content.getId(), content))
                .toList();
    }

    /**
     * 批量读取回退封面，使查询次数保持常量，不随页面项目数增长。
     */
    private List<ContentSummaryResponse> toSummaries(List<Content> contents) {
        if (contents.isEmpty()) {
            return List.of();
        }
        List<UUID> ids = contents.stream().map(Content::getId).toList();
        Map<UUID, MediaAsset> firstMediaByContent = new LinkedHashMap<>();
        for (MediaAsset media : mediaAssetRepository.findByContentIdInOrderByCreatedAtAsc(ids)) {
            if (media.getContent() != null) {
                firstMediaByContent.putIfAbsent(media.getContent().getId(), media);
            }
        }
        return contents.stream()
                .map(content -> toSummary(content, firstMediaByContent.get(content.getId())))
                .toList();
    }

    /**
     * 提取内容关联的标签名称列表，按名称升序排序。
     *
     * @param content 内容实体
     * @return 标签名称列表
     */
    private List<String> tagNames(Content content) {
        return content.getTags().stream()
                .sorted(Comparator.comparing(Tag::getName))
                .map(Tag::getName)
                .toList();
    }

    /**
     * 获取内容封面的预签名 URL。
     * <p>
     * 优先使用显式设置的 coverMedia，若未设置则使用第一条媒体资源。
     *
     * @param content 内容实体
     * @return 封面预签名 URL 或 null
     */
    private String presignedCoverUrl(Content content) {
        MediaAsset coverMedia = content.getCoverMedia();
        if (coverMedia == null) {
            // 回退到第一条媒体资源
            coverMedia = content.getMediaAssets().stream()
                    .min(Comparator.comparing(MediaAsset::getCreatedAt))
                    .orElse(null);
        }
        if (coverMedia == null) {
            return null;
        }
        return mediaAdminService.getPresignedUrl(coverMedia.getId());
    }

    private String presignedCoverUrl(Content content, MediaAsset fallbackCover) {
        MediaAsset coverMedia = content.getCoverMedia() == null
                ? fallbackCover
                : content.getCoverMedia();
        return coverMedia == null ? null : mediaAdminService.getPresignedUrl(coverMedia.getId());
    }
}
