package com.caoqiang.blog.content.service;

import com.caoqiang.blog.content.dto.AdminContentRequest;
import com.caoqiang.blog.content.dto.AdminContentResponse;
import com.caoqiang.blog.content.dto.AdminMediaRequest;
import com.caoqiang.blog.content.dto.AdminMediaResponse;
import com.caoqiang.blog.content.dto.ContentDetailResponse;
import com.caoqiang.blog.content.dto.ContentSummaryResponse;
import com.caoqiang.blog.content.dto.MediaAssetResponse;
import com.caoqiang.blog.content.dto.RecommendationResponse;
import com.caoqiang.blog.content.dto.TagRequest;
import com.caoqiang.blog.content.dto.TagResponse;
import com.caoqiang.blog.content.entity.Content;
import com.caoqiang.blog.content.entity.ContentStatus;
import com.caoqiang.blog.content.entity.ContentType;
import com.caoqiang.blog.content.entity.MediaAsset;
import com.caoqiang.blog.content.entity.MediaAssetType;
import com.caoqiang.blog.content.entity.Tag;
import com.caoqiang.blog.content.repository.ContentRepository;
import com.caoqiang.blog.content.repository.MediaAssetRepository;
import com.caoqiang.blog.content.repository.TagRepository;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.response.PageResponse;
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
public class ContentService {

    /** 最大每页条数，防止前端传入过大的 size 导致性能问题 */
    private static final int MAX_PAGE_SIZE = 50;

    private final ContentRepository contentRepository;
    private final LikeRepository likeRepository;

    public ContentService(ContentRepository contentRepository, LikeRepository likeRepository) {
        this.contentRepository = contentRepository;
        this.likeRepository = likeRepository;
    }

    /**
     * 获取推荐内容，结果缓存在 Redis 中（key = "all"）。
     * <p>
     * 返回三组推荐列表：置顶内容、最新内容、最热内容（按点赞数排序），每组最多 10 条。
     *
     * @return 推荐内容响应
     */
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
        return new PageResponse<>(
                result.getContent().stream().map(this::toSummary).toList(),
                safePage,
                safeSize,
                result.getTotalElements()
        );
    }

    /**
     * 获取单篇已发布内容的详情，包含正文、媒体资源、点赞状态等。
     *
     * @param id          内容 UUID
     * @param currentUser 当前登录用户（可为 null，未登录时 likedByCurrentUser 为 false）
     * @return 内容详情响应
     * @throws BusinessException 内容不存在或未发布时抛出 404
     */
    @Transactional(readOnly = true)
    public ContentDetailResponse detail(UUID id, AuthenticatedUser currentUser) {
        Content content = contentRepository.findByIdAndStatus(id, ContentStatus.PUBLISHED)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
        // 查询当前用户是否已点赞该内容
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
            // 基础条件：已发布且有发布时间
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

            // 关键词模糊搜索：匹配标题、摘要、正文
            if (StringUtils.hasText(query)) {
                String keyword = "%" + query.trim().toLowerCase(Locale.ROOT) + "%";
                predicates.add(criteriaBuilder.or(
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("title")), keyword),
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("summary")), keyword),
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("bodyMarkdown")), keyword)
                ));
            }

            // 标签过滤：归一化 slug 后通过 INNER JOIN 查询，多标签取交集
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

    /**
     * 将 Content 实体转换为列表摘要 DTO。
     *
     * @param content 内容实体
     * @return 内容摘要响应
     */
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
     * 获取内容的封面图 URL。
     * <p>
     * 优先返回显式设置的 coverMedia 的公开 URL，
     * 若未设置则回退到第一条关联媒体资源的 URL，都没有则返回 null。
     *
     * @param content 内容实体
     * @return 封面图 URL 或 null
     */
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
