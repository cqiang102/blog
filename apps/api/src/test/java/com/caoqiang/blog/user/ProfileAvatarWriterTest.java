package com.caoqiang.blog.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.user.application.service.ProfileAvatarWriter;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ProfileAvatarWriterTest {

    @Mock
    private UserRepository userRepository;

    private ProfileAvatarWriter writer;

    @BeforeEach
    void setUp() {
        writer = new ProfileAvatarWriter(userRepository);
    }

    @Test
    void updatesActiveUsersAvatarReference() {
        User user = User.register("user@example.com", "hash", "用户");
        String avatarUrl = "/minio/blog-media/avatars/user.png";
        when(userRepository.findById(user.getId())).thenReturn(Optional.of(user));

        User updated = writer.updateAvatar(user.getId(), avatarUrl);

        assertThat(updated).isSameAs(user);
        assertThat(user.getAvatarUrl()).isEqualTo(avatarUrl);
    }

    @Test
    void rejectsMissingUsers() {
        User user = User.register("user@example.com", "hash", "用户");
        when(userRepository.findById(user.getId())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> writer.updateAvatar(user.getId(), "/avatar.png"))
                .isInstanceOf(BusinessException.class)
                .hasMessage("登录状态无效");
    }
}
