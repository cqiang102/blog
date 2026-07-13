package com.caoqiang.blog.auth.application.service;

import com.caoqiang.blog.auth.application.dto.GithubOAuth2User;
import com.caoqiang.blog.auth.domain.model.OAuthAccount;
import com.caoqiang.blog.auth.domain.model.OAuthProvider;
import com.caoqiang.blog.auth.domain.repository.OAuthAccountRepository;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.util.Map;
import java.util.Optional;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.client.userinfo.DefaultOAuth2UserService;
import org.springframework.security.oauth2.client.userinfo.OAuth2UserRequest;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * GitHub OAuth2 用户服务
 * 处理 GitHub OAuth2 登录的用户信息加载和账户关联逻辑。
 * 支持两种场景：
 * 1. 未登录用户：登录已绑定账户，或创建全新用户
 * 2. 已登录用户：将 GitHub 账户绑定到当前用户
 *
 * @author blog-mimo
 */
@Service
public class GithubOAuth2UserService extends DefaultOAuth2UserService {

    private final UserAccountService userAccountService;
    private final OAuthAccountRepository oauthAccountRepository;

    public GithubOAuth2UserService(UserAccountService userAccountService, OAuthAccountRepository oauthAccountRepository) {
        this.userAccountService = userAccountService;
        this.oauthAccountRepository = oauthAccountRepository;
    }

    @Override
    @Transactional
    public OAuth2User loadUser(OAuth2UserRequest userRequest) throws OAuth2AuthenticationException {
        return resolveUser(super.loadUser(userRequest));
    }

    GithubOAuth2User resolveUser(OAuth2User oauth2User) {
        String providerUserId = oauth2User.getName();
        Map<String, Object> attributes = oauth2User.getAttributes();

        String login = (String) attributes.get("login");
        String email = (String) attributes.get("email");
        String name = (String) attributes.get("name");
        String avatarUrl = (String) attributes.get("avatar_url");
        String bio = (String) attributes.get("bio");
        String blogUrl = (String) attributes.get("blog");

        if (providerUserId == null || providerUserId.isBlank()
                || login == null || login.isBlank()) {
            throw oauthError("invalid_user_info", "GitHub 用户信息不完整");
        }

        if (email == null || email.isBlank()) {
            email = login + "@github.local";
        }

        String nickname = (name != null && !name.isBlank()) ? name : login;

        // 检查该 GitHub 账户是否已绑定
        Optional<OAuthAccount> existingAccount = oauthAccountRepository
                .findByProviderAndProviderUserId(OAuthProvider.GITHUB, providerUserId);

        // 场景 1：该 GitHub 已绑定 → 直接登录
        if (existingAccount.isPresent()) {
            IdentityUser user = updateOAuthProfile(
                    existingAccount.get().getUserId(),
                    nickname,
                    avatarUrl
            );
            return new GithubOAuth2User(oauth2User, user);
        }

        // 场景 2：已登录用户 → 绑定 GitHub 到当前用户
        Authentication currentAuth = SecurityContextHolder.getContext().getAuthentication();
        if (currentAuth != null && currentAuth.isAuthenticated()
                && currentAuth.getPrincipal() instanceof AuthenticatedUser currentUser) {
            IdentityUser user = userAccountService.findActiveById(currentUser.id())
                    .orElseThrow(() -> oauthError("user_not_found", "当前用户不存在或已禁用"));

            if (oauthAccountRepository.findByUserIdAndProvider(
                    currentUser.id(),
                    OAuthProvider.GITHUB
            ).isPresent()) {
                throw oauthError("already_bound", "当前用户已绑定 GitHub 账号");
            }

            OAuthAccount oauthAccount = new OAuthAccount(user.id(), OAuthProvider.GITHUB, providerUserId, login);
            oauthAccountRepository.save(oauthAccount);

            user = updateOAuthProfile(user.id(), null, avatarUrl);
            return new GithubOAuth2User(oauth2User, user);
        }

        // 场景 3：未登录用户 → 仅创建全新用户，禁止按邮箱自动接管本地账户
        Optional<IdentityUser> existingUser = userAccountService.findByEmail(email);
        if (existingUser.isPresent()) {
            throw oauthError("email_already_registered", "该邮箱已注册，请先使用原账号登录后绑定 GitHub");
        }

        IdentityUser user = userAccountService.registerOAuth(
                email,
                nickname,
                avatarUrl,
                bio,
                blogUrl
        );

        OAuthAccount oauthAccount = new OAuthAccount(user.id(), OAuthProvider.GITHUB, providerUserId, login);
        oauthAccountRepository.save(oauthAccount);

        return new GithubOAuth2User(oauth2User, user);
    }

    private IdentityUser updateOAuthProfile(
            java.util.UUID userId,
            String nickname,
            String avatarUrl
    ) {
        return userAccountService.updateOAuthProfile(userId, nickname, avatarUrl)
                .orElseThrow(() -> oauthError("account_disabled", "账号已被禁用"));
    }

    private OAuth2AuthenticationException oauthError(String code, String message) {
        return new OAuth2AuthenticationException(new OAuth2Error(code), message);
    }
}
