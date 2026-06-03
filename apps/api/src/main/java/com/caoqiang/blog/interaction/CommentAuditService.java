package com.caoqiang.blog.interaction;

import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

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
    /** Spring AI 聊天客户端，用于调用 AI 模型 */
    private final ChatClient chatClient;

    /**
     * 构造函数，注入依赖
     *
     * @param commentRepository 评论仓储
     * @param chatClient        Spring AI 聊天客户端
     */
    public CommentAuditService(CommentRepository commentRepository, ChatClient chatClient) {
        this.commentRepository = commentRepository;
        this.chatClient = chatClient;
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
    @Async
    public void audit(UUID commentId) {
        try {
            commentRepository.findById(commentId).ifPresent(comment -> {
                // 调用 AI 模型进行内容审查
                String result = chatClient.prompt()
                        .user("请审查以下博客评论是否适合公开展示。评论内容：「" + comment.getBody() + "」\n\n"
                                + "请严格按以下 JSON 格式返回，不要包含其他内容：\n"
                                + "{\"status\":\"PASS或BLOCK\",\"reason\":\"原因简述\"}\n\n"
                                + "PASS=适合展示，BLOCK=不适合展示（广告、垃圾信息、人身攻击、色情、违法等）")
                        .call()
                        .content();

                // 解析 AI 返回的 JSON 结果
                String parsedStatus = "PASS";
                String parsedReason = "";
                if (result != null) {
                    String trimmed = result.trim();
                    // 解析 status 字段
                    int statusIdx = trimmed.indexOf("\"status\"");
                    if (statusIdx >= 0) {
                        int colonIdx = trimmed.indexOf(':', statusIdx);
                        if (colonIdx >= 0) {
                            String afterColon = trimmed.substring(colonIdx + 1).trim();
                            if (afterColon.startsWith("\"")) {
                                int endQuote = afterColon.indexOf('"', 1);
                                if (endQuote > 0) {
                                    parsedStatus = afterColon.substring(1, endQuote).toUpperCase();
                                }
                            }
                        }
                    }
                    // 解析 reason 字段
                    int reasonIdx = trimmed.indexOf("\"reason\"");
                    if (reasonIdx >= 0) {
                        int colonIdx = trimmed.indexOf(':', reasonIdx);
                        if (colonIdx >= 0) {
                            String afterColon = trimmed.substring(colonIdx + 1).trim();
                            if (afterColon.startsWith("\"")) {
                                int endQuote = afterColon.indexOf('"', 1);
                                if (endQuote > 0) {
                                    parsedReason = afterColon.substring(1, endQuote);
                                }
                            }
                        }
                    }
                }

                // 保存审核结果
                comment.setAuditResult(parsedStatus, parsedReason);
                commentRepository.save(comment);
                log.info("Comment {} audit result: {} - {}", commentId, parsedStatus, parsedReason);
            });
        } catch (Exception e) {
            // 审核失败不影响评论功能，只记录日志
            log.error("Comment audit failed for {}: {}", commentId, e.getMessage());
        }
    }
}
