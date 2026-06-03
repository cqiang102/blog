package com.caoqiang.blog.user;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.auth.EmailNormalizer;
import com.caoqiang.blog.common.BusinessException;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * 个人资料服务
 * <p>
 * 处理用户个人资料的业务逻辑，包括：
 * <ul>
 *   <li>获取当前用户资料</li>
 *   <li>更新个人资料（昵称、头像、简介等）</li>
 *   <li>修改密码</li>
 * </ul>
 * <p>
 * 所有写操作均使用事务管理，确保数据一致性。
 */
@Service
public class ProfileService {

    /** 用户数据访问层 */
    private final UserRepository userRepository;
    /** 密码编码器，用于密码加密和验证 */
    private final PasswordEncoder passwordEncoder;

    public ProfileService(UserRepository userRepository, PasswordEncoder passwordEncoder) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
    }

    /**
     * 获取当前用户个人资料
     *
     * @param currentUser 当前认证用户
     * @return 用户资料响应 DTO
     */
    @Transactional(readOnly = true)
    public UserProfileResponse me(AuthenticatedUser currentUser) {
        return UserProfileResponse.from(findActiveUser(currentUser));
    }

    /**
     * 更新当前用户个人资料
     * <p>
     * 仅更新请求中非空的字段，邮箱变更时检查唯一性。
     *
     * @param currentUser 当前认证用户
     * @param request     更新资料请求体
     * @return 更新后的用户资料响应 DTO
     * @throws BusinessException 如果新邮箱已被其他用户使用
     */
    @Transactional
    public UserProfileResponse update(AuthenticatedUser currentUser, UpdateProfileRequest request) {
        User user = findActiveUser(currentUser);
        // 规范化邮箱，如果请求中提供了新邮箱则使用，否则保留原邮箱
        String newEmail = StringUtils.hasText(request.email())
                ? EmailNormalizer.normalize(request.email())
                : user.getEmail();

        // 检查邮箱唯一性（仅当邮箱变更时）
        if (!user.getEmail().equalsIgnoreCase(newEmail) && userRepository.existsByEmail(newEmail)) {
            throw new BusinessException(HttpStatus.CONFLICT, "邮箱已被使用");
        }

        // 更新用户资料字段
        user.updateProfile(
                newEmail,
                StringUtils.hasText(request.nickname()) ? request.nickname().trim() : user.getNickname(),
                request.avatarUrl(),
                request.bio(),
                request.blogUrl()
        );
        return UserProfileResponse.from(user);
    }

    /**
     * 修改当前用户密码
     * <p>
     * 验证旧密码正确后，将密码更新为新密码。
     * 仅支持已设置密码的本地账号，OAuth 账号需先设置密码。
     *
     * @param currentUser 当前认证用户
     * @param request     修改密码请求体，包含旧密码和新密码
     * @throws BusinessException 如果账号未设置密码或旧密码不正确
     */
    @Transactional
    public void changePassword(AuthenticatedUser currentUser, ChangePasswordRequest request) {
        User user = findActiveUser(currentUser);

        // 检查用户是否已设置密码（OAuth 用户可能未设置）
        if (user.getPasswordHash() == null) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "该账号未设置密码，请通过 OAuth 登录后设置");
        }

        // 验证旧密码
        if (!passwordEncoder.matches(request.oldPassword(), user.getPasswordHash())) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "旧密码不正确");
        }

        // 加密并保存新密码
        user.setPasswordHash(passwordEncoder.encode(request.newPassword()));
    }

    /**
     * 查找活跃用户，如果用户不存在或非活跃状态则抛出异常
     *
     * @param currentUser 当前认证用户
     * @return 用户实体
     * @throws BusinessException 如果用户不存在或非活跃状态
     */
    private User findActiveUser(AuthenticatedUser currentUser) {
        return userRepository.findById(currentUser.id())
                .filter(User::isActive)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "登录状态无效"));
    }
}
