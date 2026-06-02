package com.caoqiang.blog.content;

import com.caoqiang.blog.ai.KnowledgeIndexService;
import com.caoqiang.blog.common.BusinessException;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.common.SlugUtils;
import java.time.Instant;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class ContentAdminService {

    private static final int MAX_PAGE_SIZE = 50;

    private final ContentRepository contentRepository;
    private final TagRepository tagRepository;
    private final KnowledgeIndexService knowledgeIndexService;

    public ContentAdminService(
            ContentRepository contentRepository,
            TagRepository tagRepository,
            KnowledgeIndexService knowledgeIndexService
    ) {
        this.contentRepository = contentRepository;
        this.tagRepository = tagRepository;
        this.knowledgeIndexService = knowledgeIndexService;
    }

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

    @Transactional(readOnly = true)
    public AdminContentResponse detail(UUID id) {
        return contentRepository.findById(id)
                .map(AdminContentResponse::from)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
    }

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

        // 发布状态的内容自动索引到向量数据库
        if (saved.getStatus() == ContentStatus.PUBLISHED) {
            try {
                knowledgeIndexService.indexContent(saved);
            } catch (Exception e) {
                System.err.println("Failed to index content " + saved.getId() + ": " + e.getMessage());
            }
        }

        return AdminContentResponse.from(saved);
    }

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

        // 发布状态的内容更新后重新索引
        if (content.getStatus() == ContentStatus.PUBLISHED) {
            try {
                knowledgeIndexService.indexContent(content);
            } catch (Exception e) {
                System.err.println("Failed to reindex content " + content.getId() + ": " + e.getMessage());
            }
        } else {
            // 非发布状态删除索引
            try {
                knowledgeIndexService.deleteContentIndex(content.getId());
            } catch (Exception e) {
                System.err.println("Failed to delete content index " + content.getId() + ": " + e.getMessage());
            }
        }

        return AdminContentResponse.from(content);
    }

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
            System.err.println("Failed to delete content index " + content.getId() + ": " + e.getMessage());
        }
    }

    private Instant publishedAt(AdminContentRequest request) {
        if (request.status() != ContentStatus.PUBLISHED) {
            return request.publishedAt();
        }
        return request.publishedAt() == null ? Instant.now() : request.publishedAt();
    }

    private String slugFor(AdminContentRequest request) {
        String source = StringUtils.hasText(request.slug()) ? request.slug() : request.title();
        return SlugUtils.from(source);
    }

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
