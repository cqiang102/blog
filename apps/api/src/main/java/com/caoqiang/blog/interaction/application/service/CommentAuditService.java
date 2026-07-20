package com.caoqiang.blog.interaction.application.service;

import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import com.caoqiang.blog.interaction.domain.repository.CommentRepository;
import java.util.Map;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.stereotype.Service;
import tools.jackson.core.type.TypeReference;
import tools.jackson.databind.ObjectMapper;

/**
 * AI 异步评论审查服务
 * <p>
 * 使用 Spring AI 的 ChatClient 对评论内容进行异步审核。
 * 位于服务层，被 {@link InteractionService} 在评论创建后调用。
 * </p>
 * <p>
 * 审核流程：
 * <ul>
 *   <li>评论创建后异步触发审核</li>
 *   <li>调用 AI 模型分析评论内容</li>
 *   <li>解析 AI 返回的 JSON 结果（PASS/BLOCK）</li>
 *   <li>更新评论的审核状态和原因</li>
 * </ul>
 * </p>
 * <p>
 * 审核标准：检查是否包含广告、垃圾信息、人身攻击、色情、违法等内容。
 * </p>
 */
@Service
public class CommentAuditService {

    private static final Logger log = LoggerFactory.getLogger(CommentAuditService.class);

    /** 评论仓储 */
    private final CommentRepository commentRepository;

    private final CommentAuditResultService resultService;
    /** Spring AI 聊天客户端，用于调用 AI 模型 */
    private final ChatClient chatClient;
    /** Jackson JSON 解析器 */
    private final ObjectMapper objectMapper;

    /**
     * 构造函数，注入依赖
     *
     * @param commentRepository 评论仓储
     * @param chatClient        Spring AI 聊天客户端
     * @param objectMapper      Jackson JSON 解析器
     */
    public CommentAuditService(
            CommentRepository commentRepository,
            CommentAuditResultService resultService,
            ChatClient chatClient,
            ObjectMapper objectMapper) {
        this.commentRepository = commentRepository;
        this.resultService = resultService;
        this.chatClient = chatClient;
        this.objectMapper = objectMapper;
    }

    /**
     * 异步审核评论
     * <p>
     * 使用 AI 模型审查评论内容是否适合公开展示。
     * 审核结果会更新到评论实体中。
     * </p>
     *
     * @param commentId 要审核的评论 ID
     */
    public void audit(UUID commentId) {
        try {
            commentRepository.findById(commentId).ifPresent(comment -> {
                // 调用 AI 模型进行内容审查
                String result = chatClient
                        .prompt()
                        .user("请审查以下博客评论是否适合公开展示。评论内容：「" + comment.getBody() + "」\n\n"
                                + "请严格按以下 JSON 格式返回，不要包含其他内容：\n"
                                + "{\"status\":\"PASS或BLOCK\",\"reason\":\"原因简述\"}\n\n"
                                + "PASS=适合展示，BLOCK=不适合展示（广告、垃圾信息、人身攻击、色情、违法等）")
                        .call()
                        .content();

                // 解析 AI 返回的 JSON 结果
                CommentStatus parsedStatus = CommentStatus.VISIBLE;
                String parsedReason = "";
                if (result != null) {
                    try {
                        String json = extractJson(result.trim());
                        Map<String, Object> auditResult = objectMapper.readValue(json, new TypeReference<>() {});
                        Object statusObj = auditResult.get("status");
                        Object reasonObj = auditResult.get("reason");
                        if (statusObj != null) {
                            String statusStr = statusObj.toString().toUpperCase();
                            if ("BLOCK".equals(statusStr)) {
                                parsedStatus = CommentStatus.BLOCKED;
                            } else {
                                parsedStatus = CommentStatus.VISIBLE;
                            }
                        }
                        if (reasonObj != null) {
                            parsedReason = reasonObj.toString();
                        }
                    } catch (Exception parseError) {
                        log.warn("Failed to parse audit result JSON");
                        log.debug("Audit result parsing details", parseError);
                    }
                }

                // 保存审核结果
                resultService.apply(commentId, parsedStatus, parsedReason);
                log.info("Comment {} audit result: {}", commentId, parsedStatus.name());
            });
        } catch (Exception e) {
            // 审核失败不影响评论功能，只记录日志
            log.error("Comment audit failed for {}: {}", commentId, e.getMessage(), e);
        }
    }

    /**
     * 从 AI 响应中提取 JSON 字符串。
     * <p>
     * AI 可能在 JSON 前后添加额外文本，此方法尝试提取第一个 JSON 对象。
     *
     * @param text AI 响应文本
     * @return JSON 字符串
     */
    private String extractJson(String text) {
        int start = text.indexOf('{');
        int end = text.lastIndexOf('}');
        if (start >= 0 && end > start) {
            return text.substring(start, end + 1);
        }
        return text;
    }
}
