package com.caoqiang.blog.auth.dto;

import jakarta.validation.constraints.NotBlank;

/**
 * 刷新令牌请求 DTO
 * 封装刷新令牌请求的数据，包含刷新令牌。
 * 位于博客系统的认证模块，是令牌刷新流程的数据载体。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>不可变数据 - 使用 Java Record 实现，所有字段都是 final 的</li>
 *   <li>数据验证 - 使用 Jakarta Validation 注解进行数据验证</li>
 *   <li>令牌必填 - 验证刷新令牌不为空</li>
 * </ul>
 *
 * <p>验证规则：</p>
 * <ul>
 *   <li>refreshToken - 必填，不为空</li>
 * </ul>
 *
 * @param refreshToken 刷新令牌字符串
 * @author blog-mimo
 */
public record RefreshTokenRequest(
        /** 刷新令牌字符串，必填，不为空 */
        @NotBlank String refreshToken
) {
}
