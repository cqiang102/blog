package com.caoqiang.blog.auth.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.auth.application.dto.GithubProfile;
import com.caoqiang.blog.auth.application.exception.GithubAccountException;
import com.caoqiang.blog.auth.domain.model.OAuthAccount;
import com.caoqiang.blog.auth.domain.model.OAuthProvider;
import com.caoqiang.blog.auth.domain.repository.OAuthAccountRepository;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class GithubAccountServiceTest {

    @Mock
    private UserAccountService userAccountService;

    @Mock
    private OAuthAccountRepository oauthAccountRepository;

    @Test
    void doesNotAutoLinkAnExistingLocalUserByEmail() {
        GithubProfile profile = profile("github-1", "owner", "owner@example.com");
        when(oauthAccountRepository.findByProviderAndProviderUserId(OAuthProvider.GITHUB, "github-1"))
                .thenReturn(Optional.empty());
        when(userAccountService.findByEmail("owner@example.com"))
                .thenReturn(Optional.of(identityUser("owner@example.com", true)));

        assertThatThrownBy(() -> service().resolve(profile, null))
                .isInstanceOfSatisfying(
                        GithubAccountException.class,
                        error -> assertThat(error.code()).isEqualTo("email_already_registered"));

        verify(oauthAccountRepository, never()).save(any());
    }

    @Test
    void rejectsADisabledLinkedUser() {
        UUID userId = UUID.randomUUID();
        OAuthAccount account = new OAuthAccount(userId, OAuthProvider.GITHUB, "github-2", "disabled");
        when(oauthAccountRepository.findByProviderAndProviderUserId(OAuthProvider.GITHUB, "github-2"))
                .thenReturn(Optional.of(account));
        when(userAccountService.updateOAuthProfile(userId, "disabled", "https://example.com/avatar.png"))
                .thenReturn(Optional.empty());

        assertThatThrownBy(() -> service().resolve(profile("github-2", "disabled", "disabled@example.com"), null))
                .isInstanceOfSatisfying(
                        GithubAccountException.class,
                        error -> assertThat(error.code()).isEqualTo("account_disabled"));
    }

    @Test
    void bindsAnUnclaimedProviderAccountToTheRequestedUser() {
        UUID userId = UUID.randomUUID();
        IdentityUser user = identityUser(userId, "owner@example.com", true);
        GithubProfile profile = profile("github-3", "owner", "owner@example.com");
        when(userAccountService.findActiveById(userId)).thenReturn(Optional.of(user));
        when(oauthAccountRepository.findByProviderAndProviderUserId(OAuthProvider.GITHUB, "github-3"))
                .thenReturn(Optional.empty());
        when(oauthAccountRepository.findByUserIdAndProvider(userId, OAuthProvider.GITHUB))
                .thenReturn(Optional.empty());
        when(userAccountService.updateOAuthProfile(userId, null, profile.avatarUrl()))
                .thenReturn(Optional.of(user));

        assertThat(service().resolve(profile, userId)).isEqualTo(user);

        verify(oauthAccountRepository).save(any(OAuthAccount.class));
    }

    private GithubAccountService service() {
        return new GithubAccountService(userAccountService, oauthAccountRepository);
    }

    private GithubProfile profile(String id, String login, String email) {
        return new GithubProfile(id, login, email, login, "https://example.com/avatar.png", "", "");
    }

    private IdentityUser identityUser(String email, boolean active) {
        return identityUser(UUID.randomUUID(), email, active);
    }

    private IdentityUser identityUser(UUID id, String email, boolean active) {
        return new IdentityUser(id, email, "Owner", null, null, null, "hash", Role.USER, active);
    }
}
