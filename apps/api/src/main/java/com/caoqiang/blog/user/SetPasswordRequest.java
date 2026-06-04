package com.caoqiang.blog.user;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 设置密码请求 DTO
 * <p>
 * 用于 OAuth 用户首次设置密码（无需旧密码）。
 *
 * @param newPassword 新密码，长度 6-100 字符
 */
public record SetPasswordRequest(
        @NotBlank(message = "新密码不能为空")
        @Size(min = 6, max = 100, message = "新密码长度必须在 6-100 之间")
        String newPassword
) {
}
