package com.caoqiang.blog.ai.chat.context;

import com.caoqiang.blog.shared.model.AuthenticatedUser;

/**
 * AI 用户上下文持有者。
 * <p>
 * 使用 {@link ThreadLocal} 在当前线程中存储已认证的用户信息，
 * 使得 AI 工具层（如 {@link AiBlogTools}）能够在不显式传递参数的情况下获取当前用户。
 * <p>
 * 生命周期：在 {@link AiChatService} 调用 AI 前设置，调用完成后清除。
 */
public final class AiUserContext {

    /** ThreadLocal 存储当前线程的认证用户 */
    private static final ThreadLocal<AuthenticatedUser> HOLDER = new ThreadLocal<>();

    private AiUserContext() {
    }

    /**
     * 设置当前线程的认证用户。
     *
     * @param user 已认证的用户信息
     */
    public static void set(AuthenticatedUser user) {
        HOLDER.set(user);
    }

    /**
     * 获取当前线程的认证用户。
     *
     * @return 已认证的用户信息，未设置时返回 null
     */
    public static AuthenticatedUser get() {
        return HOLDER.get();
    }

    /** 清除当前线程的认证用户，防止内存泄漏。 */
    public static void clear() {
        HOLDER.remove();
    }
}
