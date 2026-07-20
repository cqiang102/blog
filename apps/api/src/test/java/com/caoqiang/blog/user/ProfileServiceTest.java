package com.caoqiang.blog.user;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.content.application.api.ContentMediaService;
import com.caoqiang.blog.content.application.api.ContentMediaUpload;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.model.UploadedFile;
import com.caoqiang.blog.user.application.api.UserProfileResponse;
import com.caoqiang.blog.user.application.dto.ChangePasswordRequest;
import com.caoqiang.blog.user.application.dto.UpdateProfileRequest;
import com.caoqiang.blog.user.application.port.OAuthAccountPort;
import com.caoqiang.blog.user.application.service.ProfileAvatarWriter;
import com.caoqiang.blog.user.application.service.ProfileService;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import java.io.ByteArrayInputStream;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

@ExtendWith(MockitoExtension.class)
class ProfileServiceTest {

    private static final Instant NOW = Instant.parse("2026-07-12T08:00:00Z");

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private OAuthAccountPort oauthAccountPort;

    @Mock
    private ContentMediaService contentMediaService;

    @Mock
    private ProfileAvatarWriter profileAvatarWriter;

    private ProfileService profileService;

    private User testUser;
    private AuthenticatedUser currentUser;

    @BeforeEach
    void setUp() {
        profileService = new ProfileService(
                userRepository,
                passwordEncoder,
                oauthAccountPort,
                Clock.fixed(NOW, ZoneOffset.UTC),
                contentMediaService,
                profileAvatarWriter);
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
        AuthenticatedUser oauthCurrentUser =
                new AuthenticatedUser(oauthUser.getId(), "oauth@example.com", "OAuth用户", Role.USER);

        when(userRepository.findById(oauthUser.getId())).thenReturn(Optional.of(oauthUser));

        ChangePasswordRequest request = new ChangePasswordRequest("oldPassword", "newPassword");

        assertThatThrownBy(() -> profileService.changePassword(oauthCurrentUser, request))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("该账号未设置密码");
    }

    @Test
    void rejectEmailChangeWithoutVerification() {
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        UpdateProfileRequest request = new UpdateProfileRequest("测试用户", null, null, null, "other@example.com");

        assertThatThrownBy(() -> profileService.update(currentUser, request))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("更换邮箱需先完成新邮箱验证");

        assertThat(testUser.getEmail()).isEqualTo("test@example.com");
    }

    @Test
    void rejectSvgAvatarEvenWhenDeclaredAsImage() {
        UploadedFile file = uploadedFile(
                "avatar.svg", "image/svg+xml", "<svg><script>alert(1)</script></svg>".getBytes(StandardCharsets.UTF_8));
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));

        assertThatThrownBy(() -> profileService.uploadAndUpdateAvatar(currentUser, file))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("仅支持 JPEG、PNG、GIF 或 WebP 图片");
    }

    @Test
    void validatesUserBeforeUploadingAvatar() {
        UploadedFile file = pngAvatar();
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.empty());

        assertThatThrownBy(() -> profileService.uploadAndUpdateAvatar(currentUser, file))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("登录状态无效");

        verify(contentMediaService, never()).upload(any(), any(), any(), any());
    }

    @Test
    void updatesAvatarAfterStorageOperationsComplete() {
        UploadedFile file = pngAvatar();
        ContentMediaUpload upload = new ContentMediaUpload("minio-1", "uploads/avatars/2026/07/12/avatar.png");
        String portableUrl = "/minio/blog-media/uploads/avatars/2026/07/12/avatar.png";
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        when(contentMediaService.upload(file, "avatars/2026/07/12/", "avatar_1783843200000.png", "image/png"))
                .thenReturn(upload);
        when(contentMediaService.portableStoragePath(upload.objectKey())).thenReturn(portableUrl);
        when(contentMediaService.resolveUrl(portableUrl)).thenReturn(portableUrl + "?signed");
        when(profileAvatarWriter.updateAvatar(testUser.getId(), portableUrl)).thenReturn(testUser);

        UserProfileResponse response = profileService.uploadAndUpdateAvatar(currentUser, file);

        assertThat(response.avatarUrl()).isEqualTo(portableUrl + "?signed");
        verify(profileAvatarWriter).updateAvatar(testUser.getId(), portableUrl);
        verify(contentMediaService, never()).delete(upload);
    }

    @Test
    void compensatesAvatarUploadWhenProfileUpdateFails() {
        UploadedFile file = pngAvatar();
        ContentMediaUpload upload = new ContentMediaUpload("minio-1", "uploads/avatars/2026/07/12/avatar.png");
        String portableUrl = "/minio/blog-media/uploads/avatars/2026/07/12/avatar.png";
        when(userRepository.findById(testUser.getId())).thenReturn(Optional.of(testUser));
        when(contentMediaService.upload(file, "avatars/2026/07/12/", "avatar_1783843200000.png", "image/png"))
                .thenReturn(upload);
        when(contentMediaService.portableStoragePath(upload.objectKey())).thenReturn(portableUrl);
        when(contentMediaService.resolveUrl(portableUrl)).thenReturn(portableUrl + "?signed");
        when(profileAvatarWriter.updateAvatar(testUser.getId(), portableUrl))
                .thenThrow(new IllegalStateException("database unavailable"));

        assertThatThrownBy(() -> profileService.uploadAndUpdateAvatar(currentUser, file))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("database unavailable");

        verify(contentMediaService).delete(upload);
    }

    @Test
    void listsOAuthAccountsThroughUserApplicationPort() {
        Instant linkedAt = Instant.parse("2026-07-12T08:00:00Z");
        when(oauthAccountPort.findByUserId(testUser.getId()))
                .thenReturn(List.of(new OAuthAccountPort.LinkedOAuthAccount("GITHUB", "octocat", linkedAt)));

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

    private UploadedFile pngAvatar() {
        return uploadedFile(
                "avatar.png", "image/png", new byte[] {(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A});
    }

    private UploadedFile uploadedFile(String filename, String contentType, byte[] bytes) {
        return new UploadedFile(filename, contentType, bytes.length, () -> new ByteArrayInputStream(bytes));
    }
}
