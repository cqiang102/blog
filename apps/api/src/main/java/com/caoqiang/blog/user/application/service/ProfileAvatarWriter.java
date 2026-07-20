package com.caoqiang.blog.user.application.service;

import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Persists an uploaded avatar reference in a short transaction after storage I/O completes. */
@Service
public class ProfileAvatarWriter {

    private final UserRepository userRepository;

    public ProfileAvatarWriter(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Transactional
    public User updateAvatar(UUID userId, String avatarUrl) {
        User user = userRepository
                .findById(userId)
                .filter(User::isActive)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "登录状态无效"));
        user.setAvatarUrl(avatarUrl);
        return user;
    }
}
