package com.caoqiang.blog.content.application.service;

import com.caoqiang.blog.content.application.dto.TagRequest;
import com.caoqiang.blog.content.application.dto.TagResponse;
import com.caoqiang.blog.content.domain.model.Tag;
import com.caoqiang.blog.content.domain.repository.TagRepository;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.util.SlugUtils;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * 管理端标签 CRUD 服务。
 * <p>
 * 位于博客系统的管理端业务层，为管理员提供标签的增删改查能力。
 * 核心职责：
 * <ul>
 *   <li>标签列表查询（按名称排序）</li>
 *   <li>标签创建（slug 唯一性校验）</li>
 *   <li>标签更新（slug 冲突检测，排除自身）</li>
 *   <li>标签删除</li>
 * </ul>
 */
@Service
public class TagAdminService {

    private final TagRepository tagRepository;

    public TagAdminService(TagRepository tagRepository) {
        this.tagRepository = tagRepository;
    }

    /**
     * 查询全部标签列表，按名称升序排序。
     *
     * @return 标签响应列表
     */
    @Transactional(readOnly = true)
    public List<TagResponse> list() {
        return tagRepository.findAll(org.springframework.data.domain.Sort.by("name")).stream()
                .map(TagResponse::from)
                .toList();
    }

    /**
     * 创建标签。
     *
     * @param request 标签请求 DTO
     * @return 创建后的标签响应
     * @throws BusinessException slug 已存在时抛出 409
     */
    @Transactional
    public TagResponse create(TagRequest request) {
        String slug = slugFor(request);
        if (tagRepository.existsBySlug(slug)) {
            throw new BusinessException(HttpStatus.CONFLICT, "标签 slug 已存在");
        }
        return TagResponse.from(tagRepository.save(new Tag(request.name().trim(), slug, request.description())));
    }

    /**
     * 更新标签。
     * <p>
     * slug 冲突检测会排除当前标签自身。
     *
     * @param id      标签 UUID
     * @param request 标签请求 DTO
     * @return 更新后的标签响应
     * @throws BusinessException 标签不存在或 slug 冲突时抛出异常
     */
    @Transactional
    public TagResponse update(UUID id, TagRequest request) {
        Tag tag = tagRepository.findById(id).orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "标签不存在"));
        String slug = slugFor(request);
        // 检查 slug 是否被其他标签占用（排除自身）
        tagRepository
                .findBySlug(slug)
                .filter(existing -> !existing.getId().equals(id))
                .ifPresent(existing -> {
                    throw new BusinessException(HttpStatus.CONFLICT, "标签 slug 已存在");
                });
        tag.update(request.name().trim(), slug, request.description());
        return TagResponse.from(tag);
    }

    /**
     * 删除标签。
     *
     * @param id 标签 UUID
     * @throws BusinessException 标签不存在时抛出 404
     */
    @Transactional
    public void delete(UUID id) {
        if (!tagRepository.existsById(id)) {
            throw new BusinessException(HttpStatus.NOT_FOUND, "标签不存在");
        }
        tagRepository.deleteById(id);
    }

    /**
     * 根据请求生成 slug。
     * <p>
     * 若请求中指定了 slug 则使用之，否则从 name 生成。
     *
     * @param request 标签请求
     * @return 规范化后的 slug
     */
    private String slugFor(TagRequest request) {
        String source = StringUtils.hasText(request.slug()) ? request.slug() : request.name();
        return SlugUtils.from(source);
    }
}
