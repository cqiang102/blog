package com.caoqiang.blog.user.application.dto;

import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.model.UserStatus;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.Size;

/**
 * 更新个人资料请求 DTO
 * <p>
 * 用于用户更新自己的个人资料信息。
 * <p>
 * 所有字段均为可选，仅更新非空字段。
 * 包含参数校验：昵称最大 80 字符，简介最大 500 字符，邮箱格式校验。
 *
 * @param nickname  用户昵称，最大 80 字符
 * @param avatarUrl 头像 URL
 * @param bio       个人简介，最大 500 字符
 * @param blogUrl   个人博客 URL
 * @param email     用户邮箱，需符合邮箱格式
 */
public record UpdateProfileRequest(
        @Size(max = 80) String nickname,
        String avatarUrl,
        @Size(max = 500) String bio,
        String blogUrl,
        @Email String email
) {
}
