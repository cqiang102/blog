package com.caoqiang.blog.ai.application.api;

import com.caoqiang.blog.ai.chat.domain.repository.AiChatSessionRepository;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeDocRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AiOverviewService {

    private final AiChatSessionRepository aiChatSessionRepository;
    private final KnowledgeDocRepository knowledgeDocRepository;

    public AiOverviewService(
            AiChatSessionRepository aiChatSessionRepository, KnowledgeDocRepository knowledgeDocRepository) {
        this.aiChatSessionRepository = aiChatSessionRepository;
        this.knowledgeDocRepository = knowledgeDocRepository;
    }

    @Transactional(readOnly = true)
    public AiOverview overview() {
        return new AiOverview(aiChatSessionRepository.count(), knowledgeDocRepository.count());
    }
}
