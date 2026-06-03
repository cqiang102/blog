package com.caoqiang.blog.ai;

/**
 * AI 聊天消息角色枚举。
 * <p>
 * 定义对话中各消息的发送者角色，对应 {@link AiChatMessage#role} 字段。
 */
public enum AiMessageRole {
    /** 用户发送的消息 */
    USER,
    /** AI 助手生成的回答 */
    ASSISTANT,
    /** 工具调用的返回结果 */
    TOOL,
    /** 系统级指令/提示 */
    SYSTEM
}
