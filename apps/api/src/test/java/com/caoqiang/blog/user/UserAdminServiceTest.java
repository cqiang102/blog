package com.caoqiang.blog.user;

import com.caoqiang.blog.user.dto.AdminUserRequest;
import com.caoqiang.blog.user.dto.AdminUserResponse;
import com.caoqiang.blog.user.dto.UserProfileResponse;
import com.caoqiang.blog.user.entity.User;
import com.caoqiang.blog.user.entity.UserStatus;
import com.caoqiang.blog.user.repository.UserRepository;
import com.caoqiang.blog.user.service.UserAdminService;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.exception.BusinessException;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;

@ExtendWith(MockitoExtension.class)
class UserAdminServiceTest {

    @Mock
    private UserRepository userRepository;

    @Test
    void updateRejectsDuplicateEmail() {
        User user = User.register("reader@example.com", "hash", "读者");
        UserAdminService service = new UserAdminService(userRepository);
        AdminUserRequest request = new AdminUserRequest(
                "other@example.com",
                "读者",
                null,
                null,
                null,
                Role.USER,
                UserStatus.ACTIVE
        );
        when(userRepository.findById(user.getId())).thenReturn(Optional.of(user));
        when(userRepository.existsByEmailAndIdNot("other@example.com", user.getId())).thenReturn(true);

        assertThatThrownBy(() -> service.update(adminPrincipal(), user.getId(), request))
                .isInstanceOfSatisfying(BusinessException.class, error -> {
                    assertThat(error.status()).isEqualTo(HttpStatus.CONFLICT);
                    assertThat(error.getMessage()).isEqualTo("邮箱已被使用");
                });
    }

    @Test
    void currentAdminCannotDisableSelf() {
        User admin = User.admin("admin@example.com", "hash", "站长");
        UserAdminService service = new UserAdminService(userRepository);
        when(userRepository.findById(admin.getId())).thenReturn(Optional.of(admin));

        assertThatThrownBy(() -> service.disable(AuthenticatedUser.from(admin), admin.getId()))
                .isInstanceOfSatisfying(BusinessException.class, error -> {
                    assertThat(error.status()).isEqualTo(HttpStatus.FORBIDDEN);
                    assertThat(error.getMessage()).isEqualTo("不能禁用自己或移除自己的管理员权限");
                });
    }

    private AuthenticatedUser adminPrincipal() {
        return new AuthenticatedUser(
                UUID.fromString("00000000-0000-0000-0000-000000000001"),
                "admin@example.com",
                "站长",
                Role.ADMIN
        );
    }
}
