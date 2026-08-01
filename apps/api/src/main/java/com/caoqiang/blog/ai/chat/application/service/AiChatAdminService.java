package com.caoqiang.blog.ai.chat.application.service;

import com.caoqiang.blog.ai.chat.application.dto.AdminAiChatDetailResponse;
import com.caoqiang.blog.ai.chat.application.dto.AdminAiChatMessageResponse;
import com.caoqiang.blog.ai.chat.application.dto.AdminAiChatSessionResponse;
import com.caoqiang.blog.ai.chat.domain.model.AiChatMessage;
import com.caoqiang.blog.ai.chat.domain.model.AiChatSession;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatMessageRepository;
import com.caoqiang.blog.ai.chat.domain.repository.AiChatSessionRepository;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.shared.util.PageUtils;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.UUID;
import org.springframework.data.domain.Page;
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
    private final UserAccountService userAccountService;

    public AiChatAdminService(
            AiChatSessionRepository sessionRepository,
            AiChatMessageRepository messageRepository,
            UserAccountService userAccountService) {
        this.sessionRepository = sessionRepository;
        this.messageRepository = messageRepository;
        this.userAccountService = userAccountService;
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
        String normalizedQuery = query == null ? "" : query.trim().toLowerCase(Locale.ROOT);
        List<UUID> matchingUserIds =
                normalizedQuery.isEmpty() ? List.of() : userAccountService.findIdsMatchingIdentity(normalizedQuery);
        Page<AiChatSession> result = sessionRepository.findAll(
                filters(userId, normalizedQuery, matchingUserIds),
                PageUtils.of(page, size, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "updatedAt")));
        Map<UUID, IdentityUser> users = usersById(
                result.getContent().stream().map(AiChatSession::getUserId).toList());
        return new PageResponse<>(
                result.getContent().stream()
                        .map(session -> toSessionResponse(session, requireUser(users, session.getUserId())))
                        .toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements());
    }

    /**
     * 获取指定会话的详情，包括会话信息和所有消息列表。
     *
     * @param id 会话 ID
     * @return 包含会话信息和消息列表的详情响应
     */
    @Transactional(readOnly = true)
    public AdminAiChatDetailResponse detail(UUID id) {
        AiChatSession session = sessionRepository
                .findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));
        List<AdminAiChatMessageResponse> messages = messageRepository.findBySessionIdOrderByCreatedAtAsc(id).stream()
                .map(AdminAiChatMessageResponse::from)
                .toList();
        IdentityUser user = userAccountService
                .findById(session.getUserId())
                .orElseThrow(() -> new BusinessException(HttpStatus.INTERNAL_SERVER_ERROR, "AI 会话关联的用户不存在"));
        return new AdminAiChatDetailResponse(toSessionResponse(session, user), messages);
    }

    /**
     * 删除指定的 AI 聊天会话（逻辑删除）。
     *
     * @param id 会话 ID
     */
    @Transactional
    public void delete(UUID id) {
        AiChatSession session = sessionRepository
                .findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "AI 会话不存在"));
        session.markDeleted();
        sessionRepository.save(session);
    }

    /** 将会话实体转换为管理端响应 DTO，附带消息数和最后一条消息。 */
    private AdminAiChatSessionResponse toSessionResponse(AiChatSession session, IdentityUser user) {
        AiChatMessage lastMessage = messageRepository
                .findFirstBySessionIdOrderByCreatedAtDesc(session.getId())
                .orElse(null);
        return AdminAiChatSessionResponse.from(
                session, user, messageRepository.countBySessionId(session.getId()), lastMessage);
    }

    /** 构建 JPA 动态查询条件：按用户 ID 和关键词（标题/邮箱/昵称）过滤，排除已删除记录。 */
    private Specification<AiChatSession> filters(UUID userId, String normalizedQuery, List<UUID> matchingUserIds) {
        return (root, query, criteriaBuilder) -> {
            List<Predicate> predicates = new ArrayList<>();
            // 过滤已删除记录
            predicates.add(criteriaBuilder.equal(root.get("deleted"), false));
            if (userId != null) {
                predicates.add(criteriaBuilder.equal(root.get("userId"), userId));
            }
            if (!normalizedQuery.isEmpty()) {
                String like = "%" + normalizedQuery + "%";
                Predicate titleMatches = criteriaBuilder.like(criteriaBuilder.lower(root.get("title")), like);
                predicates.add(
                        matchingUserIds.isEmpty()
                                ? titleMatches
                                : criteriaBuilder.or(
                                        titleMatches, root.get("userId").in(matchingUserIds)));
            }
            return criteriaBuilder.and(predicates.toArray(Predicate[]::new));
        };
    }

    private Map<UUID, IdentityUser> usersById(List<UUID> userIds) {
        return userAccountService.findByIds(userIds).stream()
                .collect(java.util.stream.Collectors.toMap(
                        IdentityUser::id, java.util.function.Function.identity(), (a, b) -> a));
    }

    private IdentityUser requireUser(Map<UUID, IdentityUser> users, UUID userId) {
        IdentityUser user = users.get(userId);
        if (user == null) {
            throw new BusinessException(HttpStatus.INTERNAL_SERVER_ERROR, "AI 会话关联的用户不存在");
        }
        return user;
    }
}
