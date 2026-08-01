package com.caoqiang.blog.ai.chat.application.service;

import com.caoqiang.blog.ai.chat.domain.repository.AiChatMessageRepository;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

/**
 * AI 聊天消息审核服务。
 * <p>
 * 基于敏感词匹配（关键词 + 正则）对消息进行异步审核。
 * 命中敏感词的消息标记为 BLOCKED，未命中标记为 VISIBLE。
 */
@Service
public class AiChatAuditService {

    private static final Logger log = LoggerFactory.getLogger(AiChatAuditService.class);

    private final AiChatMessageRepository messageRepository;
    private final SensitiveWordService sensitiveWordService;

    public AiChatAuditService(AiChatMessageRepository messageRepository, SensitiveWordService sensitiveWordService) {
        this.messageRepository = messageRepository;
        this.sensitiveWordService = sensitiveWordService;
    }

    /**
     * 异步审核 AI 聊天消息。
     *
     * @param messageId 消息 ID
     */
    public void audit(UUID messageId) {
        try {
            messageRepository.findById(messageId).ifPresent(message -> {
                String content = message.getContent();
                if (content == null || content.isBlank()) {
                    message.markVisible();
                    messageRepository.save(message);
                    return;
                }

                String matchedWord = sensitiveWordService.findMatchedWord(content);
                if (matchedWord != null) {
                    message.markBlocked("命中敏感词: " + matchedWord);
                    log.info("AI chat message blocked by content policy: messageId={}", messageId);
                } else {
                    message.markVisible();
                }

                messageRepository.save(message);
            });
        } catch (Exception e) {
            log.error("AI chat message audit failed: messageId={}", messageId, e);
        }
    }
}
