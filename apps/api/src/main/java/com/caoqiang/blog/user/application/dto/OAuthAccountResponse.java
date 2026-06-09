package com.caoqiang.blog.user.application.dto;

import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.model.UserStatus;

import com.caoqiang.blog.auth.domain.model.OAuthAccount;
import java.time.Instant;

/**
 * OAuth 账户响应 DTO
 * 用于个人中心展示已绑定的第三方账号信息。
 *
 * @param provider         OAuth 提供者名称（如 GITHUB）
 * @param providerUsername 第三方平台的用户名
 * @param createdAt        绑定时间
 */
public record OAuthAccountResponse(
        String provider,
        String providerUsername,
        Instant createdAt
) {

    /**
     * 从 OAuthAccount 实体创建响应 DTO
     *
     * @param account OAuth 账户实体
     * @return OAuthAccountResponse 响应 DTO
     */
    public static OAuthAccountResponse from(OAuthAccount account) {
        return new OAuthAccountResponse(
                account.getProvider().name(),
                account.getProviderUsername(),
                account.getCreatedAt()
        );
    }
}
