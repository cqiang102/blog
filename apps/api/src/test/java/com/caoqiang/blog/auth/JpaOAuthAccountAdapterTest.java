package com.caoqiang.blog.auth;

import com.caoqiang.blog.auth.domain.model.OAuthAccount;
import com.caoqiang.blog.auth.domain.model.OAuthProvider;
import com.caoqiang.blog.auth.domain.repository.OAuthAccountRepository;
import com.caoqiang.blog.auth.infrastructure.user.JpaOAuthAccountAdapter;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class JpaOAuthAccountAdapterTest {

    @Mock
    private OAuthAccountRepository oauthAccountRepository;

    @Test
    void exposesAuthEntityAsStableLinkedAccountView() {
        UUID userId = UUID.randomUUID();
        OAuthAccount account = new OAuthAccount(userId, OAuthProvider.GITHUB, "42", "octocat");
        JpaOAuthAccountAdapter adapter = new JpaOAuthAccountAdapter(oauthAccountRepository);
        when(oauthAccountRepository.findByUserId(userId)).thenReturn(List.of(account));

        var linkedAccounts = adapter.findByUserId(userId);

        assertThat(linkedAccounts).singleElement().satisfies(linked -> {
            assertThat(linked.provider()).isEqualTo("GITHUB");
            assertThat(linked.providerUsername()).isEqualTo("octocat");
        });
    }

    @Test
    void removesExistingAccountUsingCaseInsensitiveProviderName() {
        UUID userId = UUID.randomUUID();
        OAuthAccount account = new OAuthAccount(userId, OAuthProvider.GITHUB, "42", "octocat");
        JpaOAuthAccountAdapter adapter = new JpaOAuthAccountAdapter(oauthAccountRepository);
        when(oauthAccountRepository.findByUserIdAndProvider(userId, OAuthProvider.GITHUB))
                .thenReturn(Optional.of(account));

        boolean removed = adapter.remove(userId, "github");

        assertThat(removed).isTrue();
        verify(oauthAccountRepository).delete(account);
    }
}
