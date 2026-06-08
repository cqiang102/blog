package com.caoqiang.blog.ai.chat.service;

import com.caoqiang.blog.ai.chat.dto.AdminAiChatDetailResponse;
import com.caoqiang.blog.ai.chat.dto.AdminAiChatMessageResponse;
import com.caoqiang.blog.ai.chat.dto.AdminAiChatSessionResponse;
import com.caoqiang.blog.ai.chat.entity.AiChatMessage;
import com.caoqiang.blog.ai.chat.entity.AiChatSession;
import com.caoqiang.blog.ai.chat.repository.AiChatMessageRepository;
import com.caoqiang.blog.ai.chat.repository.AiChatSessionRepository;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.response.PageResponse;
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
 * 管理端 AI 会话/消息查询服务。
 * <p>
 * 为管理员提供 AI 聊天会话的查询、详情查看和删除功能。
 * 支持按用户 ID 和关键词（标题、邮箱、昵称）进行筛选。
 */
@Service
public class AiChatAdminService {

    /** 分页查询最大每页大小 */
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

    /**
     * 分页查询 AI 聊天会话列表，支持按用户 ID 和关键词筛选。
     *
     * @param page   页码（从 0 开始）
     * @param size   每页大小（最大 {@value #MAX_PAGE_SIZE}）
     * @param userId 可选的用户 ID 筛选条件
     * @param query  可选的关键词，匹配标题、邮箱或昵称
     * @return 分页会话列表
     */
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

    /**
     * 获取指定会话的详情，包括会话信息和所有消息列表。
     *
     * @param id 会话 ID
     * @return 包含会话信息和消息列表的详情响应
     */
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

    /**
     * 删除指定的 AI 聊天会话（逻辑删除）。
     *
     * @param id 会话 ID
     */
    @Transactional
    public void delete(UUID id) {
        AiChatSession session = sessionRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));
        session.markDeleted();
        sessionRepository.save(session);
    }

    /** 将会话实体转换为管理端响应 DTO，附带消息数和最后一条消息。 */
    private AdminAiChatSessionResponse toSessionResponse(AiChatSession session) {
        AiChatMessage lastMessage = messageRepository.findFirstBySessionIdOrderByCreatedAtDesc(session.getId())
                .orElse(null);
        return AdminAiChatSessionResponse.from(
                session,
                messageRepository.countBySessionId(session.getId()),
                lastMessage
        );
    }

    /** 构建 JPA 动态查询条件：按用户 ID 和关键词（标题/邮箱/昵称）过滤，排除已删除记录。 */
    private Specification<AiChatSession> filters(UUID userId, String queryText) {
        return (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            // 过滤已删除记录
            predicates.add(criteriaBuilder.equal(root.get("deleted"), false));
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
