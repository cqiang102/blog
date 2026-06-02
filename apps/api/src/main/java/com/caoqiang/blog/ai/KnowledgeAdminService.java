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

@Service
public class KnowledgeAdminService {

    private static final int MAX_PAGE_SIZE = 100;

    private final KnowledgeDocRepository knowledgeDocRepository;

    public KnowledgeAdminService(KnowledgeDocRepository knowledgeDocRepository) {
        this.knowledgeDocRepository = knowledgeDocRepository;
    }

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

    @Transactional(readOnly = true)
    public KnowledgeDocResponse detail(UUID id) {
        return KnowledgeDocResponse.from(doc(id));
    }

    @Transactional
    public KnowledgeDocResponse create(KnowledgeDocRequest request) {
        KnowledgeDoc doc = new KnowledgeDoc(
                request.title(),
                request.sourceType(),
                normalize(request.sourceRef()),
                normalize(request.body()),
                request.enabled()
        );
        return KnowledgeDocResponse.from(knowledgeDocRepository.save(doc));
    }

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
        return KnowledgeDocResponse.from(doc);
    }

    @Transactional
    public void delete(UUID id) {
        if (!knowledgeDocRepository.existsById(id)) {
            throw new BusinessException(HttpStatus.NOT_FOUND, "知识库文档不存在");
        }
        knowledgeDocRepository.deleteById(id);
    }

    private KnowledgeDoc doc(UUID id) {
        return knowledgeDocRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "知识库文档不存在"));
    }

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

    private String normalize(String value) {
        String text = value == null ? "" : value.trim();
        return text.isEmpty() ? null : text;
    }
}
