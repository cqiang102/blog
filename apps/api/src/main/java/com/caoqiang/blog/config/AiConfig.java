package com.caoqiang.blog.config;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.MessageChatMemoryAdvisor;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.ai.chat.memory.ChatMemoryRepository;
import org.springframework.ai.chat.memory.MessageWindowChatMemory;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * AI 对话配置类。
 * <p>
 * 负责构建博客 AI 助手的核心组件：
 * <ul>
 *     <li>会话记忆（{@link ChatMemory}）— 基于滑动窗口保留最近 20 条消息，防止上下文过长</li>
 *     <li>对话客户端（{@link ChatClient}）— 配置系统提示词和记忆顾问</li>
 * </ul>
 * <p>
 * 记忆通过 {@link ChatMemoryRepository} 持久化，支持跨请求恢复对话上下文。
 * <p>
 * 工具（{@code @Tool}）在每次请求时通过 {@code .tools()} 注册，避免循环依赖。
 *
 * @author caoqiang
 */
@Configuration
public class AiConfig {

    private static final String SYSTEM_PROMPT = """
            你是个人博客的 AI 助手。你可以：
            1. 搜索和浏览博客内容
            2. 回答关于博客文章的问题
            3. 搜索知识库回答关于博主的问题
            4. 帮用户点赞、取消点赞、发表评论、删除评论
            
            涉及博客内容、博主资料、知识库事实的问题，必须先调用搜索工具，不能凭模型自身知识猜测。
            当用户询问“全部、最新、有哪些内容”时，调用 searchContent 并把 query 设为空字符串。
            当用户询问“知识库有什么、有哪些知识来源”时，调用 searchKnowledge 并把 query 设为空字符串。
            查询具体主题时使用简洁关键词；需要完整文章正文时，再调用 getContentDetail。
            searchKnowledge 结果只有 sourceType=CONTENT 时，sourceId 才是文章 ID；KNOWLEDGE_DOC 不能调用文章详情。
            只有工具确实返回空结果时，才能回答“没有内容”或“知识库为空”。
            向量结果只是候选片段，回答前要判断片段是否真的与问题相关，相关性不足时明确说未找到。
            当用户想操作时，直接执行不需要确认。
            用中文回答，语气友好专业。
            """;

    /**
     * 创建基于消息窗口的会话记忆。
     *
     * @param chatMemoryRepository 会话记忆持久化仓库
     * @return 限制为 20 条消息窗口的 ChatMemory 实例
     */
    @Bean
    public ChatMemory chatMemory(ChatMemoryRepository chatMemoryRepository) {
        return MessageWindowChatMemory.builder()
                .chatMemoryRepository(chatMemoryRepository)
                .maxMessages(20)
                .build();
    }

    /**
     * 创建 AI 对话客户端。
     * <p>
     * 仅配置系统提示词和记忆顾问，工具在请求时动态注册。
     *
     * @param builder    Spring AI 自动配置的 ChatClient 构建器
     * @param chatMemory 会话记忆实例
     * @return 配置完成的 ChatClient
     */
    @Bean
    public ChatClient chatClient(ChatClient.Builder builder, ChatMemory chatMemory) {
        return builder
                .defaultSystem(SYSTEM_PROMPT)
                .defaultAdvisors(MessageChatMemoryAdvisor.builder(chatMemory).build())
                .build();
    }
}
