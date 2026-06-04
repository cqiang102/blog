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
            
            当用户想看内容时，先搜索再展示详情。
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
