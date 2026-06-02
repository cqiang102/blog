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
public class AiChatAdminService {

    private static final int MAX_PAGE_SIZE = 100;

    private final AiChatSessionRepository sessionRepository;
    private final AiChatMessageRepository messageRepository;

    public AiChatAdminService(
            AiChatSessionRepository sessionRepository,
            AiChatMessageRepository messageRepository
    ) {
        this.sessionRepository = sessionRepository;
        this.messageRepository = messageRepository;
    }

    @Transactional(readOnly = true)
    public PageResponse<AdminAiChatSessionResponse> sessions(int page, int size, UUID userId, String query) {
        Page<AiChatSession> result = sessionRepository.findAll(
                filters(userId, query),
                PageRequest.of(
                        Math.max(0, page),
                        Math.max(1, Math.min(size, MAX_PAGE_SIZE)),
                        Sort.by(Sort.Direction.DESC, "updatedAt")
                )
        );
        return new PageResponse<>(
                result.getContent().stream().map(this::toSessionResponse).toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
    }

    @Transactional(readOnly = true)
    public AdminAiChatDetailResponse detail(UUID id) {
        AiChatSession session = sessionRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));
        List<AdminAiChatMessageResponse> messages = messageRepository.findBySessionIdOrderByCreatedAtAsc(id)
                .stream()
                .map(AdminAiChatMessageResponse::from)
                .toList();
        return new AdminAiChatDetailResponse(toSessionResponse(session), messages);
    }

    @Transactional
    public void delete(UUID id) {
        AiChatSession session = sessionRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));
        sessionRepository.delete(session);
    }

    private AdminAiChatSessionResponse toSessionResponse(AiChatSession session) {
        AiChatMessage lastMessage = messageRepository.findFirstBySessionIdOrderByCreatedAtDesc(session.getId())
                .orElse(null);
        return AdminAiChatSessionResponse.from(
                session,
                messageRepository.countBySessionId(session.getId()),
                lastMessage
        );
    }

    private Specification<AiChatSession> filters(UUID userId, String queryText) {
        return (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            if (userId != null) {
                predicates.add(criteriaBuilder.equal(root.get("user").get("id"), userId));
            }
            String normalizedQuery = queryText == null ? "" : queryText.trim().toLowerCase(Locale.ROOT);
            if (!normalizedQuery.isEmpty()) {
                String like = "%" + normalizedQuery + "%";
                predicates.add(criteriaBuilder.or(
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("title")), like),
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("user").get("email")), like),
                        criteriaBuilder.like(criteriaBuilder.lower(root.get("user").get("nickname")), like)
                ));
            }
            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
    }
}
