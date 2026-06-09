package com.caoqiang.blog.user.application.dto;

import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.model.UserStatus;

import com.caoqiang.blog.shared.model.Role;
import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;

/**
 * 管理端用户请求 DTO
 * <p>
 * 用于管理员更新用户信息，包含用户的基本资料、角色和状态。
 * <p>
 * 包含参数校验：邮箱和昵称不能为空，邮箱需符合格式且最大 320 字符，
 * 昵称最大 80 字符，简介最大 2000 字符，角色和状态不能为空。
 *
 * @param email     用户邮箱，不能为空，需符合邮箱格式，最大 320 字符
 * @param nickname  用户昵称，不能为空，最大 80 字符
 * @param avatarUrl 头像 URL
 * @param bio       个人简介，最大 2000 字符
 * @param blogUrl   个人博客 URL
 * @param role      用户角色，不能为空
 * @param status    用户状态，不能为空
 */
public record AdminUserRequest(
        @NotBlank @Email @Size(max = 320) String email,
        @NotBlank @Size(max = 80) String nickname,
        String avatarUrl,
        @Size(max = 2000) String bio,
        String blogUrl,
        @NotNull Role role,
        @NotNull UserStatus status
) {
}
