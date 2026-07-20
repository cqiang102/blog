package com.caoqiang.blog.user.application.dto;

import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.application.api.UserProfileResponse;
import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.model.UserStatus;
import java.time.Instant;
import java.util.UUID;

/**
 * 管理端用户响应 DTO
 * <p>
 * 用于管理员查看用户详情，包含用户的完整信息。
 * <p>
 * 比 {@link UserProfileResponse} 多包含用户状态和时间戳字段，
 * 便于管理员进行用户管理和状态监控。
 *
 * @param id        用户 ID
 * @param email     用户邮箱
 * @param nickname  用户昵称
 * @param avatarUrl 头像 URL
 * @param bio       个人简介
 * @param blogUrl   个人博客 URL
 * @param role      用户角色
 * @param status    用户状态
 * @param createdAt 创建时间
 * @param updatedAt 最后更新时间
 */
public record AdminUserResponse(
        UUID id,
        String email,
        String nickname,
        String avatarUrl,
        String bio,
        String blogUrl,
        Role role,
        UserStatus status,
        Instant createdAt,
        Instant updatedAt) {

    /**
     * 从用户实体创建管理端响应 DTO
     *
     * @param user 用户实体
     * @return 管理端用户响应 DTO
     */
    public static AdminUserResponse from(User user) {
        return from(user, user.getAvatarUrl());
    }

    /**
     * 从用户实体创建管理端响应 DTO（使用预签名头像 URL）
     *
     * @param user               用户实体
     * @param presignedAvatarUrl 预签名头像 URL
     * @return 管理端用户响应 DTO
     */
    public static AdminUserResponse from(User user, String presignedAvatarUrl) {
        return new AdminUserResponse(
                user.getId(),
                user.getEmail(),
                user.getNickname(),
                presignedAvatarUrl,
                user.getBio(),
                user.getBlogUrl(),
                user.getRole(),
                user.getStatus(),
                user.getCreatedAt(),
                user.getUpdatedAt());
    }
}
