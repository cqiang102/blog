package com.caoqiang.blog.user;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.auth.EmailNormalizer;
import com.caoqiang.blog.common.BusinessException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

@Service
public class ProfileService {

    private final UserRepository userRepository;

    public ProfileService(UserRepository userRepository) {
        this.userRepository = userRepository;
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

    private User findActiveUser(AuthenticatedUser currentUser) {
        return userRepository.findById(currentUser.id())
                .filter(User::isActive)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "登录状态无效"));
    }
}
