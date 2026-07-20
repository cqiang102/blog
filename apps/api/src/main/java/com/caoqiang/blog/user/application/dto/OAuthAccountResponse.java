package com.caoqiang.blog.user.application.dto;

import com.caoqiang.blog.user.application.port.OAuthAccountPort.LinkedOAuthAccount;
import java.time.Instant;

/**
 * OAuth 账户响应 DTO
 * 用于个人中心展示已绑定的第三方账号信息。
 *
 * @param provider         OAuth 提供者名称（如 GITHUB）
 * @param providerUsername 第三方平台的用户名
 * @param createdAt        绑定时间
 */
public record OAuthAccountResponse(String provider, String providerUsername, Instant createdAt) {

    /**
     * 从身份边界公开的 OAuth 账户视图创建响应 DTO
     *
     * @param account OAuth 账户视图
     * @return OAuthAccountResponse 响应 DTO
     */
    public static OAuthAccountResponse from(LinkedOAuthAccount account) {
        return new OAuthAccountResponse(account.provider(), account.providerUsername(), account.createdAt());
    }
}
