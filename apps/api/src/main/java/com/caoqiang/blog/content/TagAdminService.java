package com.caoqiang.blog.content;

import com.caoqiang.blog.common.BusinessException;
import com.caoqiang.blog.common.SlugUtils;
import java.util.Comparator;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class TagAdminService {

    private final TagRepository tagRepository;

    public TagAdminService(TagRepository tagRepository) {
        this.tagRepository = tagRepository;
    }

    @Transactional(readOnly = true)
    public List<TagResponse> list() {
        return tagRepository.findAll().stream()
                .sorted(Comparator.comparing(Tag::getName))
                .map(TagResponse::from)
                .toList();
    }

    @Transactional
    public TagResponse create(TagRequest request) {
        String slug = slugFor(request);
        if (tagRepository.existsBySlug(slug)) {
            throw new BusinessException(HttpStatus.CONFLICT, "标签 slug 已存在");
        }
        return TagResponse.from(tagRepository.save(new Tag(request.name().trim(), slug, request.description())));
    }

    @Transactional
    public TagResponse update(UUID id, TagRequest request) {
        Tag tag = tagRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "标签不存在"));
        String slug = slugFor(request);
        tagRepository.findBySlug(slug)
                .filter(existing -> !existing.getId().equals(id))
                .ifPresent(existing -> {
                    throw new BusinessException(HttpStatus.CONFLICT, "标签 slug 已存在");
                });
        tag.update(request.name().trim(), slug, request.description());
        return TagResponse.from(tag);
    }

    @Transactional
    public void delete(UUID id) {
        if (!tagRepository.existsById(id)) {
            throw new BusinessException(HttpStatus.NOT_FOUND, "标签不存在");
        }
        tagRepository.deleteById(id);
    }

    private String slugFor(TagRequest request) {
        String source = StringUtils.hasText(request.slug()) ? request.slug() : request.name();
        return SlugUtils.from(source);
    }
}
