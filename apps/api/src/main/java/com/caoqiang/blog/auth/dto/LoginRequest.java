package com.caoqiang.blog.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/**
 * 登录请求 DTO
 * 封装用户登录请求的数据，包含邮箱和密码。
 * 位于博客系统的认证模块，是用户登录流程的数据载体。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>不可变数据 - 使用 Java Record 实现，所有字段都是 final 的</li>
 *   <li>数据验证 - 使用 Jakarta Validation 注解进行数据验证</li>
 *   <li>邮箱验证 - 验证邮箱格式是否正确</li>
 *   <li>密码必填 - 验证密码不为空</li>
 * </ul>
 *
 * <p>验证规则：</p>
 * <ul>
 *   <li>email - 必填，必须是有效的邮箱格式</li>
 *   <li>password - 必填，不为空</li>
 * </ul>
 *
 * @param email    用户邮箱地址
 * @param password 用户密码
 * @author blog-mimo
 */
public record LoginRequest(
        /** 用户邮箱地址，必填，必须是有效的邮箱格式 */
        @NotBlank @Email String email,
        /** 用户密码，必填，不为空 */
        @NotBlank String password
) {
}
