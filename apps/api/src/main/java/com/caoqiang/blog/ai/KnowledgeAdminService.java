package com.caoqiang.blog.ai;

import com.caoqiang.blog.common.BusinessException;
import com.caoqiang.blog.common.PageResponse;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 知识文档管理服务。
 * <p>
 * 为管理员提供知识文档的 CRUD 操作，支持分页查询、关键词筛选，
 * 文档创建/更新时自动触发 {@link KnowledgeIndexService} 进行向量索引。
 */
@Service
public class KnowledgeAdminService {

    /** 分页查询最大每页大小 */
    private static final int MAX_PAGE_SIZE = 100;

    private final KnowledgeDocRepository knowledgeDocRepository;
    private final KnowledgeIndexService knowledgeIndexService;

    public KnowledgeAdminService(
            KnowledgeDocRepository knowledgeDocRepository,
            KnowledgeIndexService knowledgeIndexService
    ) {
        this.knowledgeDocRepository = knowledgeDocRepository;
        this.knowledgeIndexService = knowledgeIndexService;
    }

    /**
     * 分页查询知识文档列表，支持按关键词和启用状态筛选。
     *
     * @param page    页码（从 0 开始）
     * @param size    每页大小（最大 {@value #MAX_PAGE_SIZE}）
     * @param query   可选的关键词，匹配标题、来源引用和正文
     * @param enabled 可选的启用状态筛选
     * @return 分页文档列表
     */
    @Transactional(readOnly = true)
    public PageResponse<KnowledgeDocResponse> list(int page, int size, String query, Boolean enabled) {
        Page<KnowledgeDoc> result = knowledgeDocRepository.findAll(
                filters(query, enabled),
                PageRequest.of(
                        Math.max(0, page),
                        Math.max(1, Math.min(size, MAX_PAGE_SIZE)),
                        Sort.by(Sort.Direction.DESC, "updatedAt")
                )
        );
        return new PageResponse<>(
                result.getContent().stream().map(KnowledgeDocResponse::from).toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    /**
     * 获取指定知识文档的详情。
     *
     * @param id 文档 ID
     * @return 文档详情响应
     */
    @Transactional(readOnly = true)
    public KnowledgeDocResponse detail(UUID id) {
        return KnowledgeDocResponse.from(doc(id));
    }

    /**
     * 创建新的知识文档并自动触发向量索引（仅在文档启用且有正文时）。
     *
     * @param request 创建请求
     * @return 创建后的文档详情
     */
    @Transactional
    public KnowledgeDocResponse create(KnowledgeDocRequest request) {
        KnowledgeDoc doc = new KnowledgeDoc(
                request.title(),
                request.sourceType(),
                normalize(request.sourceRef()),
                normalize(request.body()),
                request.enabled()
        );
        KnowledgeDoc saved = knowledgeDocRepository.save(doc);

        if (saved.isEnabled() && saved.getBody() != null && !saved.getBody().isBlank()) {
            try {
                knowledgeIndexService.indexDocument(saved.getId());
            } catch (Exception e) {
                // 索引失败不影响文档保存
                System.err.println("Failed to index new document: " + e.getMessage());
            }
        }

        return KnowledgeDocResponse.from(saved);
    }

    /**
     * 更新知识文档并重新触发向量索引（仅在文档启用且有正文时）。
     *
     * @param id      文档 ID
     * @param request 更新请求
     * @return 更新后的文档详情
     */
    @Transactional
    public KnowledgeDocResponse update(UUID id, KnowledgeDocRequest request) {
        KnowledgeDoc doc = doc(id);
        doc.apply(
                request.title(),
                request.sourceType(),
                normalize(request.sourceRef()),
                normalize(request.body()),
                request.enabled()
        );

        if (doc.isEnabled() && doc.getBody() != null && !doc.getBody().isBlank()) {
            try {
                knowledgeIndexService.indexDocument(id);
            } catch (Exception e) {
                System.err.println("Failed to reindex document: " + e.getMessage());
            }
        }

        return KnowledgeDocResponse.from(doc);
    }

    /**
     * 删除指定的知识文档。
     *
     * @param id 文档 ID
     */
    @Transactional
    public void delete(UUID id) {
        if (!knowledgeDocRepository.existsById(id)) {
            throw new BusinessException(HttpStatus.NOT_FOUND, "知识库文档不存在");
        }
        knowledgeDocRepository.deleteById(id);
    }

    /** 根据 ID 获取知识文档，不存在时抛出异常。 */
    private KnowledgeDoc doc(UUID id) {
        return knowledgeDocRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "知识库文档不存在"));
    }

    /** 构建 JPA 动态查询条件：按启用状态和关键词（标题/来源引用/正文）过滤。 */
    private Specification<KnowledgeDoc> filters(String queryText, Boolean enabled) {
        return (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (enabled != null) {
                predicates.add(criteriaBuilder.equal(root.get("enabled"), enabled));
            }
            String normalizedQuery = queryText == null ? "" : queryText.trim().toLowerCase(Locale.ROOT);
            if (!normalizedQuery.isEmpty()) {
                String like = "%" + normalizedQuery + "%";
                predicates.add(criteriaBuilder.or(
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("title")), like),
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("sourceRef")), like),
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("body")), like)
                ));
            }
            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
    }

    /** 将字符串值标准化：去除首尾空白，空字符串转为 null。 */
    private String normalize(String value) {
        String text = value == null ? "" : value.trim();
        return text.isEmpty() ? null : text;
    }
}
