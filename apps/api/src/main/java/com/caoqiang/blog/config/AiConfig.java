package com.caoqiang.blog.config;

import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.client.advisor.MessageChatMemoryAdvisor;
import org.springframework.ai.chat.memory.ChatMemory;
import org.springframework.ai.chat.memory.ChatMemoryRepository;
import org.springframework.ai.chat.memory.MessageWindowChatMemory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * AI 对话配置类。
 * <p>
 * 负责构建博客 AI 助手的核心组件：
 * <ul>
 *     <li>会话记忆（{@link ChatMemory}）— 基于滑动窗口保留最近 20 条消息，防止上下文过长</li>
 *     <li>对话客户端（{@link ChatClient}）— 配置系统提示词和记忆顾问，支持博客内容搜索、问答、互动操作</li>
 * </ul>
 * <p>
 * 记忆通过 {@link ChatMemoryRepository} 持久化，支持跨请求恢复对话上下文。
 *
 * @author caoqiang
 */
@Configuration
public class AiConfig {

    /**
     * 创建基于消息窗口的会话记忆。
     * <p>
     * 使用滑动窗口策略，仅保留最近 {@code maxMessages} 条消息，自动淘汰早期消息以控制 Token 消耗。
     * 仅在 ChatMemoryRepository bean 存在时生效（即数据库启用时）。
     *
     * @param chatMemoryRepository 会话记忆持久化仓库
     * @return 限制为 20 条消息窗口的 ChatMemory 实例
     */
    @Bean
    @ConditionalOnBean(ChatMemoryRepository.class)
    public ChatMemory chatMemory(ChatMemoryRepository chatMemoryRepository) {
        return MessageWindowChatMemory.builder()
                .chatMemoryRepository(chatMemoryRepository)
                .maxMessages(20) // 滑动窗口大小：保留最近 20 条消息
                .build();
    }

    /**
     * 创建 AI 对话客户端（带记忆）。
     * <p>
     * 仅在 ChatMemory bean 存在时生效。
     *
     * @param builder    Spring AI 自动配置的 ChatClient 构建器
     * @param chatMemory 会话记忆实例
     * @return 配置完成的 ChatClient
     */
    @Bean
    @ConditionalOnBean(ChatMemory.class)
    public ChatClient chatClientWithMemory(ChatClient.Builder builder, ChatMemory chatMemory) {
        return builder
                .defaultSystem("""
                        你是个人博客的 AI 助手。你可以：
                        1. 搜索和浏览博客内容
                        2. 回答关于博客文章的问题
                        3. 搜索知识库回答关于博主的问题
                        4. 帮用户点赞、取消点赞、发表评论、删除评论
                        
                        当用户想看内容时，先搜索再展示详情。
                        当用户想操作时，直接执行不需要确认。
                        用中文回答，语气友好专业。
                        """)
                .defaultAdvisors(MessageChatMemoryAdvisor.builder(chatMemory).build())
                .build();
    }

    /**
     * 创建 AI 对话客户端（无记忆）。
     * <p>
     * 仅在 ChatMemory bean 不存在时生效（即数据库未启用时）。
     *
     * @param builder Spring AI 自动配置的 ChatClient 构建器
     * @return 配置完成的 ChatClient
     */
    @Bean
    @ConditionalOnBean(name = "chatMemory", value = ChatMemory.class)
    public ChatClient chatClient(ChatClient.Builder builder) {
        return builder
                .defaultSystem("""
                        你是个人博客的 AI 助手。你可以：
                        1. 搜索和浏览博客内容
                        2. 回答关于博客文章的问题
                        3. 搜索知识库回答关于博主的问题
                        4. 帮用户点赞、取消点赞、发表评论、删除评论
                        
                        当用户想看内容时，先搜索再展示详情。
                        当用户想操作时，直接执行不需要确认。
                        用中文回答，语气友好专业。
                        """)
                .build();
    }
}
