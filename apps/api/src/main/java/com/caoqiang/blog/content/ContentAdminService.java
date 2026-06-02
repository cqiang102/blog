package com.caoqiang.blog.content;

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

    public ContentAdminService(ContentRepository contentRepository, TagRepository tagRepository) {
        this.contentRepository = contentRepository;
        this.tagRepository = tagRepository;
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
        return AdminContentResponse.from(contentRepository.save(content));
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
        return AdminContentResponse.from(content);
    }

    @Transactional
    @CacheEvict(value = "recommendations", allEntries = true)
    public void archive(UUID id) {
        Content content = contentRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
        content.archive();
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
