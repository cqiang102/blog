package com.caoqiang.blog.user.application.dto;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 设置密码请求 DTO
 * <p>
 * 用于 OAuth 用户首次设置密码（无需旧密码）。
 *
 * @param newPassword 新密码，长度 8-72 字符
 */
public record SetPasswordRequest(
        @NotBlank(message = "新密码不能为空") @Size(min = 8, max = 72, message = "新密码长度必须在 8-72 之间")
        String newPassword) {}
