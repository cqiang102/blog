package com.caoqiang.blog.auth;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 注册请求 DTO
 * 封装用户注册请求的数据，包含邮箱、密码和昵称。
 * 位于博客系统的认证模块，是用户注册流程的数据载体。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>不可变数据 - 使用 Java Record 实现，所有字段都是 final 的</li>
 *   <li>数据验证 - 使用 Jakarta Validation 注解进行数据验证</li>
 *   <li>邮箱验证 - 验证邮箱格式是否正确</li>
 *   <li>密码强度 - 验证密码长度在 8-80 之间</li>
 *   <li>昵称限制 - 验证昵称不为空且长度不超过 80</li>
 * </ul>
 *
 * <p>验证规则：</p>
 * <ul>
 *   <li>email - 必填，必须是有效的邮箱格式</li>
 *   <li>password - 必填，长度必须在 8-80 之间</li>
 *   <li>nickname - 必填，长度不超过 80</li>
 * </ul>
 *
 * @param email    用户邮箱地址
 * @param password 用户密码
 * @param nickname 用户昵称
 * @author blog-mimo
 */
public record RegisterRequest(
        /** 用户邮箱地址，必填，必须是有效的邮箱格式 */
        @NotBlank @Email String email,
        /** 用户密码，必填，长度必须在 8-80 之间 */
        @NotBlank @Size(min = 8, max = 80) String password,
        /** 用户昵称，必填，长度不超过 80 */
        @NotBlank @Size(max = 80) String nickname,
        /** 邮箱验证码，必填，6 位数字 */
        @NotBlank @Size(min = 6, max = 6) String code
) {
}
