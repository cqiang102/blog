package com.caoqiang.blog.user.application.dto;

import com.caoqiang.blog.user.domain.model.User;
import com.caoqiang.blog.user.domain.model.UserStatus;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 修改密码请求 DTO
 * <p>
 * 用于用户修改自己的登录密码。
 * <p>
 * 包含参数校验：旧密码和新密码均不能为空，新密码长度在 8-72 之间。
 *
 * @param oldPassword 旧密码，用于验证用户身份
 * @param newPassword 新密码，长度 8-72 字符
 */
public record ChangePasswordRequest(
        @NotBlank(message = "旧密码不能为空")
        String oldPassword,

        @NotBlank(message = "新密码不能为空")
        @Size(min = 8, max = 72, message = "新密码长度必须在 8-72 之间")
        String newPassword
) {
}
