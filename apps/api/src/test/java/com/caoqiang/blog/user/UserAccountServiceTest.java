package com.caoqiang.blog.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class UserAccountServiceTest {

    @Mock
    private UserRepository userRepository;

    @Test
    void exposesAnImmutableIdentitySnapshot() {
        User user = User.register("reader@example.com", "hash", "Reader");
        user.setAvatarUrl("https://example.com/old.png");
        when(userRepository.findById(user.getId())).thenReturn(Optional.of(user));
        UserAccountService service = new UserAccountService(userRepository);

        IdentityUser snapshot = service.findActiveById(user.getId()).orElseThrow();
        user.setNickname("Changed later");

        assertThat(snapshot.id()).isEqualTo(user.getId());
        assertThat(snapshot.email()).isEqualTo("reader@example.com");
        assertThat(snapshot.nickname()).isEqualTo("Reader");
        assertThat(snapshot.avatarUrl()).isEqualTo("https://example.com/old.png");
        assertThat(snapshot.hasPassword()).isTrue();
        assertThat(snapshot.active()).isTrue();
    }

    @Test
    void updatesOAuthProfileInsideTheUserModule() {
        User user = User.register("reader@example.com", null, "Old name");
        when(userRepository.findById(user.getId())).thenReturn(Optional.of(user));
        UserAccountService service = new UserAccountService(userRepository);

        IdentityUser snapshot = service.updateOAuthProfile(user.getId(), "GitHub name", "https://example.com/new.png")
                .orElseThrow();

        assertThat(user.getNickname()).isEqualTo("GitHub name");
        assertThat(user.getAvatarUrl()).isEqualTo("https://example.com/new.png");
        assertThat(snapshot.nickname()).isEqualTo("GitHub name");
        assertThat(snapshot.avatarUrl()).isEqualTo("https://example.com/new.png");
        assertThat(snapshot.hasPassword()).isFalse();
    }

    @Test
    void delegatesIdentityKeywordSearchWithoutExposingTheRepository() {
        UUID userId = UUID.randomUUID();
        when(userRepository.findIdsMatchingIdentity("reader")).thenReturn(List.of(userId));
        UserAccountService service = new UserAccountService(userRepository);

        assertThat(service.findIdsMatchingIdentity("  reader  ")).containsExactly(userId);
        verify(userRepository).findIdsMatchingIdentity("reader");
    }
}
