package com.caoqiang.blog.user;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.auth.EmailNormalizer;
import com.caoqiang.blog.common.BusinessException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class ProfileService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;

    public ProfileService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    @Transactional(readOnly = true)
    public UserProfileResponse me(AuthenticatedUser currentUser) {
        return UserProfileResponse.from(findActiveUser(currentUser));
    }

    @Transactional
    public UserProfileResponse update(AuthenticatedUser currentUser, UpdateProfileRequest request) {
        User user = findActiveUser(currentUser);
        String newEmail = StringUtils.hasText(request.email())
                ? EmailNormalizer.normalize(request.email())
                : user.getEmail();

        if (!user.getEmail().equalsIgnoreCase(newEmail) && userRepository.existsByEmail(newEmail)) {
            throw new BusinessException(HttpStatus.CONFLICT, "邮箱已被使用");
        }

        user.updateProfile(
                newEmail,
                StringUtils.hasText(request.nickname()) ? request.nickname().trim() : user.getNickname(),
                request.avatarUrl(),
                request.bio(),
                request.blogUrl()
        );
        return UserProfileResponse.from(user);
    }

    @Transactional
    public void changePassword(AuthenticatedUser currentUser, ChangePasswordRequest request) {
        User user = findActiveUser(currentUser);

        if (user.getPasswordHash() == null) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "该账号未设置密码，请通过 OAuth 登录后设置");
        }

        if (!passwordEncoder.matches(request.oldPassword(), user.getPasswordHash())) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "旧密码不正确");
        }

        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));
    }

    private User findActiveUser(AuthenticatedUser currentUser) {
        return userRepository.findById(currentUser.id())
                .filter(User::isActive)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "登录状态无效"));
    }
}
