package com.caoqiang.blog.interaction;

import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Service;

@Service
public class CommentAuditService {

    private static final Logger log = LoggerFactory.getLogger(CommentAuditService.class);

    private final CommentRepository commentRepository;
    private final ChatClient chatClient;

    public CommentAuditService(CommentRepository commentRepository, ChatClient chatClient) {
        this.commentRepository = commentRepository;
        this.chatClient = chatClient;
    }

    @Async
    public void audit(UUID commentId) {
        try {
            commentRepository.findById(commentId).ifPresent(comment -> {
                String result = chatClient.prompt()
                        .user("请审查以下博客评论是否适合公开展示。评论内容：「" + comment.getBody() + "」\n\n"
                                + "请严格按以下 JSON 格式返回，不要包含其他内容：\n"
                                + "{\"status\":\"PASS或BLOCK\",\"reason\":\"原因简述\"}\n\n"
                                + "PASS=适合展示，BLOCK=不适合展示（广告、垃圾信息、人身攻击、色情、违法等）")
                        .call()
                        .content();

                String parsedStatus = "PASS";
                String parsedReason = "";
                if (result != null) {
                    String trimmed = result.trim();
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

                comment.setAuditResult(parsedStatus, parsedReason);
                commentRepository.save(comment);
                log.info("Comment {} audit result: {} - {}", commentId, parsedStatus, parsedReason);
            });
        } catch (Exception e) {
            log.error("Comment audit failed for {}: {}", commentId, e.getMessage());
        }
    }
}
