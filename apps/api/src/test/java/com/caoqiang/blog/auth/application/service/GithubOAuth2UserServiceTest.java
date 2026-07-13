package com.caoqiang.blog.auth.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.auth.domain.model.OAuthAccount;
import com.caoqiang.blog.auth.domain.model.OAuthProvider;
import com.caoqiang.blog.auth.domain.repository.OAuthAccountRepository;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.oauth2.core.OAuth2AuthenticationException;
import org.springframework.security.oauth2.core.user.OAuth2User;

@ExtendWith(MockitoExtension.class)
class GithubOAuth2UserServiceTest {

    @Mock
    private UserAccountService userAccountService;

    @Mock
    private OAuthAccountRepository oauthAccountRepository;

    @Mock
    private OAuth2User oauth2User;

    @AfterEach
    void clearSecurityContext() {
        SecurityContextHolder.clearContext();
    }

    @Test
    void doesNotAutoLinkAnExistingLocalUserByEmail() {
        GithubOAuth2UserService service = service();
        IdentityUser localUser = identityUser("owner@example.com", "Owner", true);
        stubGithubUser("github-1", "owner", "owner@example.com");
        when(oauthAccountRepository.findByProviderAndProviderUserId(
                OAuthProvider.GITHUB,
                "github-1"
        )).thenReturn(Optional.empty());
        when(userAccountService.findByEmail("owner@example.com")).thenReturn(Optional.of(localUser));

        assertThatThrownBy(() -> service.resolveUser(oauth2User))
                .isInstanceOfSatisfying(OAuth2AuthenticationException.class, error ->
                        assertThat(error.getError().getErrorCode())
                                .isEqualTo("email_already_registered")
                );

        verify(oauthAccountRepository, never()).save(org.mockito.ArgumentMatchers.any());
    }

    @Test
    void rejectsADisabledLinkedUser() {
        GithubOAuth2UserService service = service();
        UUID disabledUserId = UUID.randomUUID();
        OAuthAccount account = new OAuthAccount(
                disabledUserId,
                OAuthProvider.GITHUB,
                "github-2",
                "disabled"
        );
        stubGithubUser("github-2", "disabled", "disabled@example.com");
        when(oauthAccountRepository.findByProviderAndProviderUserId(
                OAuthProvider.GITHUB,
                "github-2"
        )).thenReturn(Optional.of(account));
        assertThatThrownBy(() -> service.resolveUser(oauth2User))
                .isInstanceOfSatisfying(OAuth2AuthenticationException.class, error ->
                        assertThat(error.getError().getErrorCode()).isEqualTo("account_disabled")
                );
    }

    private GithubOAuth2UserService service() {
        return new GithubOAuth2UserService(userAccountService, oauthAccountRepository);
    }

    private IdentityUser identityUser(String email, String nickname, boolean active) {
        return new IdentityUser(
                UUID.randomUUID(),
                email,
                nickname,
                null,
                null,
                null,
                "hash",
                Role.USER,
                active
        );
    }

    private void stubGithubUser(String id, String login, String email) {
        when(oauth2User.getName()).thenReturn(id);
        when(oauth2User.getAttributes()).thenReturn(Map.of(
                "login", login,
                "email", email,
                "name", login,
                "avatar_url", "https://example.com/avatar.png",
                "bio", "",
                "blog", ""
        ));
    }
}
