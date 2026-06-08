package com.caoqiang.blog.auth;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.user.User;
import com.caoqiang.blog.user.UserRepository;
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
 * 1. 未登录用户：创建新用户或关联到同邮箱用户
 * 2. 已登录用户：将 GitHub 账户绑定到当前用户
 *
 * @author blog-mimo
 */
@Service
public class GithubOAuth2UserService extends DefaultOAuth2UserService {

    private final UserRepository userRepository;
    private final OAuthAccountRepository oauthAccountRepository;

    public GithubOAuth2UserService(UserRepository userRepository, OAuthAccountRepository oauthAccountRepository) {
        this.userRepository = userRepository;
        this.oauthAccountRepository = oauthAccountRepository;
    }

    @Override
    @Transactional
    public OAuth2User loadUser(OAuth2UserRequest userRequest) throws OAuth2AuthenticationException {
        OAuth2User oauth2User = super.loadUser(userRequest);

        String providerUserId = oauth2User.getName();
        Map<String, Object> attributes = oauth2User.getAttributes();

        String login = (String) attributes.get("login");
        String email = (String) attributes.get("email");
        String name = (String) attributes.get("name");
        String avatarUrl = (String) attributes.get("avatar_url");
        String bio = (String) attributes.get("bio");
        String blogUrl = (String) attributes.get("blog");

        if (email == null || email.isBlank()) {
            email = login + "@github.local";
        }

        String nickname = (name != null && !name.isBlank()) ? name : login;

        // 检查该 GitHub 账户是否已绑定
        Optional<OAuthAccount> existingAccount = oauthAccountRepository
                .findByProviderAndProviderUserId(OAuthProvider.GITHUB, providerUserId);

        // 场景 1：该 GitHub 已绑定 → 直接登录
        if (existingAccount.isPresent()) {
            User user = existingAccount.get().getUser();
            user.setAvatarUrl(avatarUrl);
            user.setNickname(nickname);
            return new GithubOAuth2User(oauth2User, user);
        }

        // 场景 2：已登录用户 → 绑定 GitHub 到当前用户
        Authentication currentAuth = SecurityContextHolder.getContext().getAuthentication();
        if (currentAuth != null && currentAuth.isAuthenticated()
                && currentAuth.getPrincipal() instanceof AuthenticatedUser currentUser) {
            User user = userRepository.findById(currentUser.id())
                    .orElseThrow(() -> new OAuth2AuthenticationException(
                            new OAuth2Error("user_not_found"), "当前用户不存在"));

            OAuthAccount oauthAccount = new OAuthAccount(user, OAuthProvider.GITHUB, providerUserId, login);
            oauthAccountRepository.save(oauthAccount);

            user.setAvatarUrl(avatarUrl);
            return new GithubOAuth2User(oauth2User, user);
        }

        // 场景 3：未登录用户 → 创建新用户或关联到同邮箱用户
        Optional<User> existingUser = userRepository.findByEmail(email);
        User user;
        if (existingUser.isPresent()) {
            user = existingUser.get();
        } else {
            user = User.register(email, null, nickname);
            user.setAvatarUrl(avatarUrl);
            user.setBio(bio);
            user.setBlogUrl(blogUrl);
            user = userRepository.save(user);
        }

        OAuthAccount oauthAccount = new OAuthAccount(user, OAuthProvider.GITHUB, providerUserId, login);
        oauthAccountRepository.save(oauthAccount);

        return new GithubOAuth2User(oauth2User, user);
    }
}
