package com.caoqiang.blog.auth.application.service;

import com.caoqiang.blog.auth.application.dto.GithubProfile;
import com.caoqiang.blog.auth.application.exception.GithubAccountException;
import com.caoqiang.blog.auth.domain.model.OAuthAccount;
import com.caoqiang.blog.auth.domain.model.OAuthProvider;
import com.caoqiang.blog.auth.domain.repository.OAuthAccountRepository;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Owns the single account-resolution policy shared by every GitHub OAuth adapter. */
@Service
public class GithubAccountService {

    private static final Logger log = LoggerFactory.getLogger(GithubAccountService.class);

    private final UserAccountService userAccountService;
    private final OAuthAccountRepository oauthAccountRepository;

    public GithubAccountService(UserAccountService userAccountService, OAuthAccountRepository oauthAccountRepository) {
        this.userAccountService = userAccountService;
        this.oauthAccountRepository = oauthAccountRepository;
    }

    @Transactional
    public IdentityUser resolve(GithubProfile profile, UUID bindingUserId) {
        if (bindingUserId != null) {
            return bind(profile, bindingUserId);
        }
        return login(profile);
    }

    private IdentityUser bind(GithubProfile profile, UUID userId) {
        IdentityUser user = userAccountService
                .findActiveById(userId)
                .orElseThrow(() -> error("user_not_found", HttpStatus.BAD_REQUEST, "用户不存在或已禁用"));

        oauthAccountRepository
                .findByProviderAndProviderUserId(OAuthProvider.GITHUB, profile.providerUserId())
                .ifPresent(account -> {
                    if (!account.getUserId().equals(userId)) {
                        throw error("provider_already_bound", HttpStatus.CONFLICT, "该 GitHub 账号已被其他用户绑定");
                    }
                });

        if (oauthAccountRepository
                .findByUserIdAndProvider(userId, OAuthProvider.GITHUB)
                .isPresent()) {
            throw error("already_bound", HttpStatus.CONFLICT, "当前用户已绑定 GitHub 账号");
        }

        oauthAccountRepository.save(
                new OAuthAccount(user.id(), OAuthProvider.GITHUB, profile.providerUserId(), profile.login()));
        IdentityUser updated = updateOAuthProfile(user.id(), null, profile.avatarUrl());
        log.info("GitHub 账号绑定成功: userId={}", userId);
        return updated;
    }

    private IdentityUser login(GithubProfile profile) {
        var existingAccount =
                oauthAccountRepository.findByProviderAndProviderUserId(OAuthProvider.GITHUB, profile.providerUserId());
        if (existingAccount.isPresent()) {
            IdentityUser user =
                    updateOAuthProfile(existingAccount.get().getUserId(), profile.nickname(), profile.avatarUrl());
            log.info("GitHub 账号登录成功: userId={}", user.id());
            return user;
        }

        if (userAccountService.findByEmail(profile.email()).isPresent()) {
            throw error("email_already_registered", HttpStatus.CONFLICT, "该邮箱已注册，请先使用原账号登录后绑定 GitHub");
        }

        IdentityUser user = userAccountService.registerOAuth(
                profile.email(), profile.nickname(), profile.avatarUrl(), profile.bio(), profile.blogUrl());
        oauthAccountRepository.save(
                new OAuthAccount(user.id(), OAuthProvider.GITHUB, profile.providerUserId(), profile.login()));
        log.info("GitHub 账号注册成功: userId={}", user.id());
        return user;
    }

    private IdentityUser updateOAuthProfile(UUID userId, String nickname, String avatarUrl) {
        return userAccountService
                .updateOAuthProfile(userId, nickname, avatarUrl)
                .orElseThrow(() -> error("account_disabled", HttpStatus.FORBIDDEN, "账号已被禁用"));
    }

    private GithubAccountException error(String code, HttpStatus status, String message) {
        return new GithubAccountException(code, status, message);
    }
}
