package com.caoqiang.blog.content.application.service;

import com.caoqiang.blog.content.application.dto.AdminContentRequest;
import com.caoqiang.blog.content.application.dto.AdminContentResponse;
import com.caoqiang.blog.content.application.dto.AdminMediaRequest;
import com.caoqiang.blog.content.application.dto.AdminMediaResponse;
import com.caoqiang.blog.content.application.dto.ContentDetailResponse;
import com.caoqiang.blog.content.application.dto.ContentSummaryResponse;
import com.caoqiang.blog.content.application.dto.MediaAssetResponse;
import com.caoqiang.blog.content.application.dto.RecommendationResponse;
import com.caoqiang.blog.content.application.dto.TagRequest;
import com.caoqiang.blog.content.application.dto.TagResponse;
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import com.caoqiang.blog.content.domain.model.Tag;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.repository.MediaAssetRepository;
import com.caoqiang.blog.content.domain.repository.TagRepository;

import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeIndexService;
import com.caoqiang.blog.shared.domain.event.DomainEventPublisher;
import com.caoqiang.blog.shared.domain.event.content.ContentPublishedEvent;
import com.caoqiang.blog.shared.domain.event.content.ContentArchivedEvent;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.shared.util.SlugUtils;
import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * 管理端内容 CRUD 服务。
 * <p>
 * 位于博客系统的管理端业务层，为管理员提供内容的增删改查能力。
 * 核心职责：
 * <ul>
 *   <li>内容列表分页查询（管理端，不过滤状态）</li>
 *   <li>内容详情查看</li>
 *   <li>内容创建与更新（含 slug 唯一性校验、标签关联）</li>
 *   <li>内容归档</li>
 *   <li>与 AI 知识库索引联动：创建/更新时同步索引，归档或变为非发布状态时删除索引</li>
 * </ul>
 * 写操作会清除推荐缓存（{@code @CacheEvict}），确保推荐列表数据一致性。
 */
@Service
public class ContentAdminService {

    private static final Logger log = LoggerFactory.getLogger(ContentAdminService.class);

    /** 最大每页条数 */
    private static final int MAX_PAGE_SIZE = 50;

    private final ContentRepository contentRepository;
    private final TagRepository tagRepository;
    private final MediaAssetRepository mediaAssetRepository;

    /** AI 知识库索引服务，用于内容发布后同步向量数据库 */
    private final KnowledgeIndexService knowledgeIndexService;
    /** 领域事件发布器 */
    private final DomainEventPublisher domainEventPublisher;

    public ContentAdminService(
            ContentRepository contentRepository,
            TagRepository tagRepository,
            MediaAssetRepository mediaAssetRepository,
            KnowledgeIndexService knowledgeIndexService,
            DomainEventPublisher domainEventPublisher
    ) {
        this.contentRepository = contentRepository;
        this.tagRepository = tagRepository;
        this.mediaAssetRepository = mediaAssetRepository;
        this.knowledgeIndexService = knowledgeIndexService;
        this.domainEventPublisher = domainEventPublisher;
    }

    /**
     * 分页查询所有内容（管理端，不过滤状态），按创建时间倒序。
     *
     * @param page 页码，从 0 开始
     * @param size 每页条数，上限 {@link #MAX_PAGE_SIZE}
     * @return 分页内容响应
     */
    @Transactional(readOnly = true)
    public PageResponse<AdminContentResponse> list(int page, int size) {
        PageRequest pageRequest = PageRequest.of(
                Math.max(0, page),
                Math.max(1, Math.min(size, MAX_PAGE_SIZE)),
                Sort.by(Sort.Direction.DESC, "createdAt")
        );
        Page<Content> result = contentRepository.findAll(pageRequest);
        return new PageResponse<>(
                result.getContent().stream().map(AdminContentResponse::from).toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    /**
     * 获取内容详情（管理端）。
     *
     * @param id 内容 UUID
     * @return 管理端内容详情响应
     * @throws BusinessException 内容不存在时抛出 404
     */
    @Transactional(readOnly = true)
    public AdminContentResponse detail(UUID id) {
        return contentRepository.findById(id)
                .map(AdminContentResponse::from)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
    }

    /**
     * 创建内容。
     * <p>
     * 若状态为 PUBLISHED，则自动索引到 AI 向量数据库。
     * 创建成功后清除推荐缓存。
     *
     * @param request 管理端内容请求 DTO
     * @return 创建后的内容响应
     * @throws BusinessException slug 已存在时抛出 409
     */
    @Transactional
    @CacheEvict(value = "recommendations", allEntries = true)
    public AdminContentResponse create(AdminContentRequest request) {
        String slug = slugFor(request);
        if (contentRepository.existsBySlug(slug)) {
            throw new BusinessException(HttpStatus.CONFLICT, "内容 slug 已存在");
        }

        Content content = new Content(
                request.title().trim(),
                slug,
                request.type() == null ? ContentType.ARTICLE : request.type(),
                request.status() == null ? ContentStatus.DRAFT : request.status(),
                request.summary(),
                request.bodyMarkdown(),
                request.pinned(),
                publishedAt(request),
                tags(request.tagSlugs())
        );
        Content saved = contentRepository.save(content);

        // 处理媒体资源
        MediaAsset firstMediaAsset = null;
        if (request.mediaUrls() != null && !request.mediaUrls().isEmpty()) {
            for (String url : request.mediaUrls()) {
                if (StringUtils.hasText(url)) {
                    MediaAsset mediaAsset = new MediaAsset(
                            saved,
                            request.type() == ContentType.VIDEO ? MediaAssetType.VIDEO : MediaAssetType.IMAGE,
                            MediaAsset.EXTERNAL_BUCKET,
                            MediaAsset.EXTERNAL_BUCKET + "/" + UUID.randomUUID(),
                            url.trim(),
                            null,
                            null,
                            null,
                            null,
                            null,
                            null
                    );
                    MediaAsset savedMedia = mediaAssetRepository.save(mediaAsset);
                    if (firstMediaAsset == null) {
                        firstMediaAsset = savedMedia;
                    }
                }
            }
        }

        // 设置封面
        if (StringUtils.hasText(request.coverUrl()) && firstMediaAsset != null) {
            // 查找匹配的媒体资源作为封面
            MediaAsset coverMedia = saved.getMediaAssets().stream()
                    .filter(ma -> request.coverUrl().equals(ma.getPublicUrl()))
                    .findFirst()
                    .orElse(firstMediaAsset);
            saved.setCoverMedia(coverMedia);
        } else if (firstMediaAsset != null) {
            // 默认使用第一个媒体作为封面
            saved.setCoverMedia(firstMediaAsset);
        }

        // 发布状态的内容自动索引到向量数据库
        if (saved.getStatus() == ContentStatus.PUBLISHED) {
            try {
                knowledgeIndexService.indexContent(saved);
            } catch (Exception e) {
                log.error("Failed to index content {}: {}", saved.getId(), e.getMessage(), e);
            }
            // 发布领域事件
            domainEventPublisher.publishEvent(new ContentPublishedEvent(saved.getId(), saved.getTitle(), saved.getSlug()));
        }

        return AdminContentResponse.from(saved);
    }

    /**
     * 更新内容。
     * <p>
     * 更新后根据状态同步向量索引：
     * <ul>
     *   <li>PUBLISHED：重新索引</li>
     *   <li>非 PUBLISHED：删除已有索引</li>
     * </ul>
     * 更新成功后清除推荐缓存。
     *
     * @param id      内容 UUID
     * @param request 管理端内容请求 DTO
     * @return 更新后的内容响应
     * @throws BusinessException 内容不存在或 slug 冲突时抛出异常
     */
    @Transactional
    @CacheEvict(value = "recommendations", allEntries = true)
    public AdminContentResponse update(UUID id, AdminContentRequest request) {
        Content content = contentRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
        String slug = slugFor(request);
        if (contentRepository.existsBySlugAndIdNot(slug, id)) {
            throw new BusinessException(HttpStatus.CONFLICT, "内容 slug 已存在");
        }

        content.apply(
                request.title().trim(),
                slug,
                request.type() == null ? content.getType() : request.type(),
                request.status() == null ? content.getStatus() : request.status(),
                request.summary(),
                request.bodyMarkdown(),
                request.pinned(),
                publishedAt(request),
                tags(request.tagSlugs())
        );

        // 处理媒体资源：删除旧的外链媒体，添加新的
        if (request.mediaUrls() != null) {
            // 先清除封面引用，避免 flush 时 Hibernate 检测到指向已删除实体的引用
            content.setCoverMedia(null);

            // 删除旧的外链媒体
            List<MediaAsset> oldMediaAssets = content.getMediaAssets().stream()
                    .filter(ma -> MediaAsset.EXTERNAL_BUCKET.equals(ma.getBucket()))
                    .toList();
            mediaAssetRepository.deleteAll(oldMediaAssets);
            mediaAssetRepository.flush();
            contentRepository.flush();

            // 添加新的媒体资源
            MediaAsset firstMediaAsset = null;
            List<MediaAsset> newMediaAssets = new java.util.ArrayList<>();
            for (String url : request.mediaUrls()) {
                if (StringUtils.hasText(url)) {
                    MediaAsset mediaAsset = new MediaAsset(
                            content,
                            request.type() == ContentType.VIDEO ? MediaAssetType.VIDEO : MediaAssetType.IMAGE,
                            MediaAsset.EXTERNAL_BUCKET,
                            MediaAsset.EXTERNAL_BUCKET + "/" + UUID.randomUUID(),
                            url.trim(),
                            null,
                            null,
                            null,
                            null,
                            null,
                            null
                    );
                    MediaAsset savedMedia = mediaAssetRepository.save(mediaAsset);
                    newMediaAssets.add(savedMedia);
                    if (firstMediaAsset == null) {
                        firstMediaAsset = savedMedia;
                    }
                }
            }

            // 设置封面（从新保存的媒体列表中查找，避免访问可能包含已删除实体的旧集合）
            if (StringUtils.hasText(request.coverUrl())) {
                MediaAsset coverMedia = newMediaAssets.stream()
                        .filter(ma -> request.coverUrl().equals(ma.getPublicUrl()))
                        .findFirst()
                        .orElse(firstMediaAsset);
                content.setCoverMedia(coverMedia);
            } else if (firstMediaAsset != null) {
                content.setCoverMedia(firstMediaAsset);
            } else {
                content.setCoverMedia(null);
            }
        }

        // 发布状态的内容更新后重新索引
        if (content.getStatus() == ContentStatus.PUBLISHED) {
            try {
                knowledgeIndexService.indexContent(content);
            } catch (Exception e) {
                log.error("Failed to reindex content {}: {}", content.getId(), e.getMessage(), e);
            }
            // 发布领域事件
            domainEventPublisher.publishEvent(new ContentPublishedEvent(content.getId(), content.getTitle(), content.getSlug()));
        } else {
            // 非发布状态删除索引
            try {
                knowledgeIndexService.deleteContentIndex(content.getId());
            } catch (Exception e) {
                log.error("Failed to delete content index {}: {}", content.getId(), e.getMessage(), e);
            }
        }

        return AdminContentResponse.from(content);
    }

    /**
     * 归档内容。
     * <p>
     * 将内容状态设为 ARCHIVED，并删除对应的向量索引。
     * 操作成功后清除推荐缓存。
     *
     * @param id 内容 UUID
     * @throws BusinessException 内容不存在时抛出 404
     */
    @Transactional
    @CacheEvict(value = "recommendations", allEntries = true)
    public void archive(UUID id) {
        Content content = contentRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
        content.archive();

        // 归档后删除向量索引
        try {
            knowledgeIndexService.deleteContentIndex(content.getId());
        } catch (Exception e) {
            log.error("Failed to delete content index {}: {}", content.getId(), e.getMessage(), e);
        }

        // 发布领域事件
        domainEventPublisher.publishEvent(new ContentArchivedEvent(content.getId()));
    }

    /**
     * 确定发布时间。
     * <p>
     * 非发布状态直接使用请求中的值；发布状态若未指定则默认为当前时间。
     *
     * @param request 管理端内容请求
     * @return 发布时间
     */
    private Instant publishedAt(AdminContentRequest request) {
        if (request.status() != ContentStatus.PUBLISHED) {
            return request.publishedAt();
        }
        return request.publishedAt() == null ? Instant.now() : request.publishedAt();
    }

    /**
     * 根据请求生成 slug。
     * <p>
     * 若请求中指定了 slug 则使用之，否则从 title 生成。
     *
     * @param request 管理端内容请求
     * @return 规范化后的 slug
     */
    private String slugFor(AdminContentRequest request) {
        String source = StringUtils.hasText(request.slug()) ? request.slug() : request.title();
        return SlugUtils.from(source);
    }

    /**
     * 根据 tag slug 列表查询并返回标签实体集合。
     *
     * @param tagSlugs 标签 slug 列表
     * @return 标签实体集合
     * @throws BusinessException 存在未创建的标签时抛出 400
     */
    private Set<Tag> tags(List<String> tagSlugs) {
        List<String> normalized = tagSlugs == null ? List.of() : tagSlugs.stream()
                .filter(StringUtils::hasText)
                .map(slug -> SlugUtils.from(slug).toLowerCase(Locale.ROOT))
                .distinct()
                .toList();
        if (normalized.isEmpty()) {
            return Set.of();
        }

        List<Tag> tags = tagRepository.findBySlugIn(normalized);
        if (tags.size() != normalized.size()) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "存在未创建的标签");
        }
        return new LinkedHashSet<>(tags);
    }
}
