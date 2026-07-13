package com.caoqiang.blog.user;

import com.caoqiang.blog.user.application.dto.ChangePasswordRequest;
import com.caoqiang.blog.user.application.dto.SetPasswordRequest;
import com.caoqiang.blog.user.application.dto.UpdateProfileRequest;
import com.caoqiang.blog.user.application.api.UserProfileResponse;
import com.caoqiang.blog.user.application.port.OAuthAccountPort;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.model.UserStatus;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import com.caoqiang.blog.user.application.service.ProfileService;
import com.caoqiang.blog.content.application.api.ContentMediaService;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.exception.BusinessException;
import java.time.Clock;
import java.time.Instant;
import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.dromara.x.file.storage.core.FileStorageService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.mock.web.MockMultipartFile;

@ExtendWith(MockitoExtension.class)
class ProfileServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private FileStorageService fileStorageService;

    @Mock
    private OAuthAccountPort oauthAccountPort;

    @Mock
    private ContentMediaService contentMediaService;

    private ProfileService profileService;

    private User testUser;
    private AuthenticatedUser currentUser;

    @BeforeEach
    void setUp() {
        profileService = new ProfileService(userRepository, passwordEncoder,
                fileStorageService, oauthAccountPort, Clock.systemUTC(), "minio-1",
                contentMediaService);
        testUser = User.register("test@example.com", "hashedPassword", "测试用户");
        currentUser = new AuthenticatedUser(testUser.getId(), "test@example.com", "测试用户", Role.USER);
    }

    @Test
    void changePasswordSuccessfully() {
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        when(passwordEncoder.matches("oldPassword", "hashedPassword")).thenReturn(true);
        when(passwordEncoder.encode("newPassword")).thenReturn("newHashedPassword");

        ChangePasswordRequest request = new ChangePasswordRequest("oldPassword", "newPassword");
        profileService.changePassword(currentUser, request);

        verify(passwordEncoder).matches("oldPassword", "hashedPassword");
        verify(passwordEncoder).encode("newPassword");
        assertThat(testUser.getPasswordHash()).isEqualTo("newHashedPassword");
    }

    @Test
    void rejectWrongOldPassword() {
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        when(passwordEncoder.matches("wrongPassword", "hashedPassword")).thenReturn(false);

        ChangePasswordRequest request = new ChangePasswordRequest("wrongPassword", "newPassword");

        assertThatThrownBy(() -> profileService.changePassword(currentUser, request))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("旧密码不正确");
    }

    @Test
    void rejectPasswordChangeForOAuthUser() {
        User oauthUser = User.register("oauth@example.com", null, "OAuth用户");
        AuthenticatedUser oauthCurrentUser = new AuthenticatedUser(oauthUser.getId(), "oauth@example.com", "OAuth用户", Role.USER);

        when(userRepository.findById(oauthUser.getId())).thenReturn(Optional.of(oauthUser));

        ChangePasswordRequest request = new ChangePasswordRequest("oldPassword", "newPassword");

        assertThatThrownBy(() -> profileService.changePassword(oauthCurrentUser, request))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("该账号未设置密码");
    }

    @Test
    void rejectEmailChangeWithoutVerification() {
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        UpdateProfileRequest request = new UpdateProfileRequest(
                "测试用户",
                null,
                null,
                null,
                "other@example.com"
        );

        assertThatThrownBy(() -> profileService.update(currentUser, request))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("更换邮箱需先完成新邮箱验证");

        assertThat(testUser.getEmail()).isEqualTo("test@example.com");
    }

    @Test
    void rejectSvgAvatarEvenWhenDeclaredAsImage() {
        MockMultipartFile file = new MockMultipartFile(
                "file",
                "avatar.svg",
                "image/svg+xml",
                "<svg><script>alert(1)</script></svg>".getBytes(StandardCharsets.UTF_8)
        );

        assertThatThrownBy(() -> profileService.uploadAvatar(file))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("仅支持 JPEG、PNG、GIF 或 WebP 图片");
    }

    @Test
    void listsOAuthAccountsThroughUserApplicationPort() {
        Instant linkedAt = Instant.parse("2026-07-12T08:00:00Z");
        when(oauthAccountPort.findByUserId(testUser.getId())).thenReturn(List.of(
                new OAuthAccountPort.LinkedOAuthAccount("GITHUB", "octocat", linkedAt)
        ));

        var accounts = profileService.getOAuthAccounts(currentUser);

        assertThat(accounts).singleElement().satisfies(account -> {
            assertThat(account.provider()).isEqualTo("GITHUB");
            assertThat(account.providerUsername()).isEqualTo("octocat");
            assertThat(account.createdAt()).isEqualTo(linkedAt);
        });
    }

    @Test
    void unbindsOAuthAccountThroughUserApplicationPort() {
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        when(oauthAccountPort.remove(testUser.getId(), "github")).thenReturn(true);

        profileService.unbindOAuthAccount(currentUser, "github");

        verify(oauthAccountPort).remove(testUser.getId(), "github");
    }
}
