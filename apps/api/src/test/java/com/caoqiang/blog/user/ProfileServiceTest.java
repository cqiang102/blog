package com.caoqiang.blog.user;

import com.caoqiang.blog.user.application.dto.ChangePasswordRequest;
import com.caoqiang.blog.user.application.dto.SetPasswordRequest;
import com.caoqiang.blog.user.application.dto.UpdateProfileRequest;
import com.caoqiang.blog.user.application.dto.UserProfileResponse;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.model.UserStatus;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import com.caoqiang.blog.user.application.service.ProfileService;
import com.caoqiang.blog.content.application.service.MediaAdminService;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.auth.domain.repository.OAuthAccountRepository;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.exception.BusinessException;
import java.time.Clock;
import java.util.Optional;
import java.util.UUID;
import org.dromara.x.file.storage.core.FileStorageService;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.crypto.password.PasswordEncoder;

@ExtendWith(MockitoExtension.class)
class ProfileServiceTest {

    @Mock
    private UserRepository userRepository;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private FileStorageService fileStorageService;

    @Mock
    private OAuthAccountRepository oauthAccountRepository;

    @Mock
    private MediaAdminService mediaAdminService;

    private ProfileService profileService;

    private User testUser;
    private AuthenticatedUser currentUser;

    @BeforeEach
    void setUp() {
        profileService = new ProfileService(userRepository, passwordEncoder,
                fileStorageService, oauthAccountRepository, Clock.systemUTC(), "minio-1",
                mediaAdminService);
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
}
