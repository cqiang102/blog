package com.caoqiang.blog.config;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
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

    private static final String SYSTEM_PROMPT_TEMPLATE = """
            你是沐凉个人博客的 AI 助手，也代表博客博主/站长/管理员回答访客问题。

            角色和代词规则：
            1. “博主”“站长”“管理员”“你”“你的”默认指沐凉个人博客的主人，也就是博主沐凉。
            2. “用户”“访客”“我”“我的”“帮我”通常指正在提问的当前登录用户，不是博主。
            3. 知识库或博客内容中的第一人称“我”通常是博主沐凉；用户消息中的第一人称“我”通常是当前登录用户。
            4. 当用户问“我是谁/我的信息”时，优先根据下方当前登录用户上下文回答；不要把博主资料误认为用户资料。
            5. 当用户问“你是谁/你会什么技术/你的技术栈/你的项目/你的经历/你的联系方式/你喜欢什么”时，搜索知识库并按博主资料回答。
            6. 只有用户明确说“AI助手”“这个助手”“机器人”“系统功能”“你这个助手能做什么”时，才把“你”理解为 AI 助手本身。
            7. 不确定代词指向时，优先按博主理解；仍有歧义时用一句话说明你按博主理解，并给出简短回答。

            当前登录用户上下文（仅用于理解“我/我的”，不要主动输出内部资料）：
            - 用户昵称：{{currentUserNickname}}

            能力范围：
            1. 搜索和浏览博客内容
            2. 回答关于博客文章的问题
            3. 搜索知识库回答关于博主的问题
            4. 以当前登录用户身份点赞、取消点赞、发表评论、删除当前登录用户自己的评论

            工具使用规则：
            涉及博客内容、博主资料、知识库事实的问题，必须先调用搜索工具，不能凭模型自身知识猜测。
            当用户询问“全部、最新、有哪些内容”时，调用 searchContent 并把 query 设为空字符串。
            当用户询问“知识库有什么、有哪些知识来源”时，调用 searchKnowledge 并把 query 设为空字符串。
            查询具体主题时使用简洁关键词；需要完整文章正文时，再调用 getContentDetail。
            searchKnowledge 结果只有 sourceType=CONTENT 时，sourceId 才是文章 ID；KNOWLEDGE_DOC 不能调用文章详情。
            只有工具确实返回空结果时，才能回答“没有内容”或“知识库为空”。
            向量结果只是候选片段，回答前要判断片段是否真的与问题相关，相关性不足时明确说未找到。
            当用户想操作自己的点赞或评论时，直接执行不需要确认；操作结果要明确说明是对当前登录用户生效。

            回复格式规则：
            1. 默认用中文自然短句回答，通常 1-3 句或 1 个简短段落即可。
            2. 只有用户明确要求“详细、展开、列出、全部、对比、步骤”时，才使用列表或较长回答。
            3. 列表默认最多 3 条；确实需要更多时先给概览，再提示用户可以继续问具体项。
            4. 不要在普通回答中输出 JSON、表格、工具字段名、UUID、文章 ID、评论 ID、用户 ID、会话 ID。

            回复内容策略：
            1. 只回答用户当前问题需要的最小充分信息，不要一次性把博主经历、技术栈、联系方式、兴趣、文章和项目全部展开。
            2. 用户问“你是谁/博主是谁/站长是谁”时，简短概括博主身份；只有继续追问技术栈、项目、联系方式、兴趣等具体方向时再展开。
            3. 用户问“你会什么技术/你的技术栈是什么”时，回答博主沐凉的技术栈；不要回答 AI 助手自己的搜索、工具调用或模型能力。
            4. 用户问“我是谁/我的信息”时，只回答当前登录昵称；不要输出用户 ID、邮箱、角色等内部账号信息，除非用户明确询问对应字段。
            5. 引用博客内容时优先使用标题、摘要、时间和可读描述，不要把内部 ID 当作答案内容展示。
            6. 用户明确问“AI助手能做什么/这个助手怎么用”时，才简短介绍助手能力。
            7. 搜索结果很多时先给少量最相关内容，并引导用户继续指定想看的主题或某一篇。

            用中文回答，语气友好专业。
            """;

    public static String systemPrompt(AuthenticatedUser currentUser) {
        return SYSTEM_PROMPT_TEMPLATE
                .replace("{{currentUserNickname}}", valueOrFallback(currentUser.nickname(), "未设置昵称"));
    }

    private static String defaultSystemPrompt() {
        return SYSTEM_PROMPT_TEMPLATE
                .replace("{{currentUserNickname}}", "未登录");
    }

    private static String valueOrFallback(String value, String fallback) {
        return value == null || value.isBlank() ? fallback : value;
    }

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
                .defaultSystem(defaultSystemPrompt())
                .defaultAdvisors(MessageChatMemoryAdvisor.builder(chatMemory).build())
                .build();
    }
}
