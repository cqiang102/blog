package com.caoqiang.blog.interaction;

import com.caoqiang.blog.common.BusinessException;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.content.ContentRepository;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class InteractionAdminService {

    private static final int MAX_PAGE_SIZE = 100;

    private final LikeRepository likeRepository;
    private final ViewRecordRepository viewRecordRepository;
    private final ContentRepository contentRepository;

    public InteractionAdminService(
            LikeRepository likeRepository,
            ViewRecordRepository viewRecordRepository,
            ContentRepository contentRepository
    ) {
        this.likeRepository = likeRepository;
        this.viewRecordRepository = viewRecordRepository;
        this.contentRepository = contentRepository;
    }

    @Transactional(readOnly = true)
    public PageResponse<AdminLikeResponse> likes(int page, int size, UUID contentId, UUID userId) {
        Page<Like> result = likeRepository.findAll(
                filters(contentId, userId),
                pageRequest(page, size)
        );
        return new PageResponse<>(
                result.getContent().stream().map(AdminLikeResponse::from).toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    @Transactional
    public void deleteLike(UUID id) {
        Like like = likeRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "点赞记录不存在"));
        likeRepository.delete(like);
        contentRepository.incrementLikeCount(like.getContent().getId(), -1);
    }

    @Transactional(readOnly = true)
    public PageResponse<AdminViewRecordResponse> views(int page, int size, UUID contentId, UUID userId) {
        Page<ViewRecord> result = viewRecordRepository.findAll(
                filters(contentId, userId),
                pageRequest(page, size)
        );
        return new PageResponse<>(
                result.getContent().stream().map(AdminViewRecordResponse::from).toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    @Transactional
    public void deleteView(UUID id) {
        ViewRecord viewRecord = viewRecordRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "浏览记录不存在"));
        viewRecordRepository.delete(viewRecord);
        contentRepository.incrementViewCount(viewRecord.getContent().getId(), -1);
    }

    private <T> Specification<T> filters(UUID contentId, UUID userId) {
        return (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (contentId != null) {
                predicates.add(criteriaBuilder.equal(root.get("content").get("id"), contentId));
            }
            if (userId != null) {
                predicates.add(criteriaBuilder.equal(root.get("user").get("id"), userId));
            }
            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
    }

    private PageRequest pageRequest(int page, int size) {
        return PageRequest.of(
                Math.max(0, page),
                Math.max(1, Math.min(size, MAX_PAGE_SIZE)),
                Sort.by(Sort.Direction.DESC, "createdAt")
        );
    }
}
