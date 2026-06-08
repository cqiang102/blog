package com.caoqiang.blog.auth;

import java.util.List;

/**
 * OAuth 提供者信息响应 DTO。
 * <p>
 * 用于返回系统支持的 OAuth 提供者列表及授权 URL，替代 {@code Map<String, Object>}。
 *
 * @param enabled        已启用的 OAuth 提供者列表
 * @param reserved       已预留但未启用的 OAuth 提供者列表
 * @param githubLoginUrl GitHub 登录授权 URL
 * @author caoqiang
 */
public record OAuthProvidersResponse(
        List<OAuthProvider> enabled,
        List<OAuthProvider> reserved,
        String githubLoginUrl
) {
}
