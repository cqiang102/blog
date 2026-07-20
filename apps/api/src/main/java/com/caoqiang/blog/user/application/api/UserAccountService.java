package com.caoqiang.blog.user.application.api;

import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.repository.UserRepository;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * Public user-module API used by authentication workflows.
 *
 * <p>It keeps UserRepository private to the user module while registration,
 * lookup and bootstrap remain part of the same database transaction.</p>
 */
@Service
public class UserAccountService {

    private final UserRepository userRepository;

    public UserAccountService(UserRepository userRepository) {
        this.userRepository = userRepository;
    }

    @Transactional(readOnly = true)
    public boolean existsByEmail(String email) {
        return userRepository.existsByEmail(email);
    }

    @Transactional(readOnly = true)
    public Optional<IdentityUser> findByEmail(String email) {
        return userRepository.findByEmail(email).map(this::snapshot);
    }

    @Transactional(readOnly = true)
    public Optional<IdentityUser> findById(UUID userId) {
        return userRepository.findById(userId).map(this::snapshot);
    }

    @Transactional(readOnly = true)
    public Optional<IdentityUser> findActiveById(UUID userId) {
        return userRepository.findById(userId).filter(User::isActive).map(this::snapshot);
    }

    @Transactional(readOnly = true)
    public List<IdentityUser> findByIds(Collection<UUID> userIds) {
        if (userIds.isEmpty()) {
            return List.of();
        }
        return userRepository.findAllById(userIds).stream().map(this::snapshot).toList();
    }

    @Transactional(readOnly = true)
    public List<UUID> findIdsMatchingIdentity(String query) {
        if (query == null || query.isBlank()) {
            return List.of();
        }
        return userRepository.findIdsMatchingIdentity(query.trim());
    }

    @Transactional
    public IdentityUser registerLocal(String email, String passwordHash, String nickname) {
        return snapshot(userRepository.save(User.register(email, passwordHash, nickname)));
    }

    @Transactional
    public IdentityUser registerOAuth(String email, String nickname, String avatarUrl, String bio, String blogUrl) {
        User user = User.register(email, null, nickname);
        user.setAvatarUrl(avatarUrl);
        user.setBio(bio);
        user.setBlogUrl(blogUrl);
        return snapshot(userRepository.save(user));
    }

    @Transactional
    public IdentityUser createAdmin(String email, String passwordHash, String nickname) {
        return snapshot(userRepository.save(User.admin(email, passwordHash, nickname)));
    }

    @Transactional
    public Optional<IdentityUser> updateOAuthProfile(UUID userId, String nickname, String avatarUrl) {
        return userRepository.findById(userId).filter(User::isActive).map(user -> {
            if (nickname != null) {
                user.setNickname(nickname);
            }
            user.setAvatarUrl(avatarUrl);
            return snapshot(user);
        });
    }

    private IdentityUser snapshot(User user) {
        return new IdentityUser(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getAvatarUrl(),
                user.getBio(),
                user.getBlogUrl(),
                user.getPasswordHash(),
                user.getRole(),
                user.isActive());
    }
}
