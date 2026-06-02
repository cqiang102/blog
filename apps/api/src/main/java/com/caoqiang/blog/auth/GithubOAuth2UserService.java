package com.caoqiang.blog.auth;

import com.caoqiang.blog.user.User;
import com.caoqiang.blog.user.UserRepository;
import java.util.Map;
import java.util.Optional;
import org.springframework.security.oauth2.client.userinfo.DefaultOAuth2UserService;
import org.springframework.security.oauth2.client.userinfo.OAuth2UserRequest;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.user.OAuth2User;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

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

        Optional<OAuthAccount> existingAccount = oauthAccountRepository
                .findByProviderAndProviderUserId(OAuthProvider.GITHUB, providerUserId);

        User user;
        if (existingAccount.isPresent()) {
            user = existingAccount.get().getUser();
            user.setAvatarUrl(avatarUrl);
            user.setNickname(nickname);
        } else {
            Optional<User> existingUser = userRepository.findByEmail(email);
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
        }

        return new GithubOAuth2User(oauth2User, user);
    }
}
