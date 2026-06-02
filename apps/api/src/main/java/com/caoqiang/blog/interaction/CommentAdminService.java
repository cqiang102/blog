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
public class CommentAdminService {

    private static final int MAX_PAGE_SIZE = 100;

    private final CommentRepository commentRepository;
    private final ContentRepository contentRepository;

    public CommentAdminService(CommentRepository commentRepository, ContentRepository contentRepository) {
        this.commentRepository = commentRepository;
        this.contentRepository = contentRepository;
    }

    @Transactional(readOnly = true)
    public PageResponse<AdminCommentResponse> list(
            int page,
            int size,
            CommentStatus status,
            UUID contentId,
            UUID userId
    ) {
        Page<Comment> result = commentRepository.findAll(
                filters(status, contentId, userId),
                pageRequest(page, size)
        );
        return new PageResponse<>(
                result.getContent().stream().map(AdminCommentResponse::from).toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    @Transactional
    public AdminCommentResponse setStatus(UUID id, CommentStatus targetStatus) {
        Comment comment = commentRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "评论不存在"));
        CommentStatus previousStatus = comment.getStatus();
        if (previousStatus != targetStatus) {
            comment.setStatus(targetStatus);
            syncCommentCount(comment, previousStatus, targetStatus);
        }
        return AdminCommentResponse.from(comment);
    }

    @Transactional
    public void delete(UUID id) {
        setStatus(id, CommentStatus.DELETED);
    }

    private Specification<Comment> filters(CommentStatus status, UUID contentId, UUID userId) {
        return (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (status != null) {
                predicates.add(criteriaBuilder.equal(root.get("status"), status));
            }
            if (contentId != null) {
                predicates.add(criteriaBuilder.equal(root.get("content").get("id"), contentId));
            }
            if (userId != null) {
                predicates.add(criteriaBuilder.equal(root.get("user").get("id"), userId));
            }
            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
    }

    private void syncCommentCount(Comment comment, CommentStatus previousStatus, CommentStatus targetStatus) {
        if (previousStatus == CommentStatus.VISIBLE && targetStatus != CommentStatus.VISIBLE) {
            contentRepository.incrementCommentCount(comment.getContent().getId(), -1);
        } else if (previousStatus != CommentStatus.VISIBLE && targetStatus == CommentStatus.VISIBLE) {
            contentRepository.incrementCommentCount(comment.getContent().getId(), 1);
        }
    }

    private PageRequest pageRequest(int page, int size) {
        return PageRequest.of(
                Math.max(0, page),
                Math.max(1, Math.min(size, MAX_PAGE_SIZE)),
                Sort.by(Sort.Direction.DESC, "createdAt")
        );
    }
}
