package com.caoqiang.blog.user;

import com.caoqiang.blog.auth.Role;
import java.util.UUID;

/**
 * 用户资料响应 DTO
 * <p>
 * 用于返回当前登录用户的个人资料信息。
 * <p>
 * 包含用户的基本信息（ID、邮箱、昵称等）和角色信息，
 * 不包含敏感信息如密码哈希。
 *
 * @param id        用户 ID
 * @param email     用户邮箱
 * @param nickname  用户昵称
 * @param avatarUrl 头像 URL
 * @param bio       个人简介
 * @param blogUrl   个人博客 URL
 * @param role      用户角色
 */
public record UserProfileResponse(
        UUID id,
        String email,
        String nickname,
        String avatarUrl,
        String bio,
        String blogUrl,
        Role role
) {

    /**
     * 从用户实体创建响应 DTO
     *
     * @param user 用户实体
     * @return 用户资料响应 DTO
     */
    public static UserProfileResponse from(User user) {
        return new UserProfileResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                user.getAvatarUrl(),
                user.getBio(),
                user.getBlogUrl(),
                user.getRole()
        );
    }
}
