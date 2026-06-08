package com.caoqiang.blog.auth.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;

/**
 * 发送验证码请求 DTO
 * 用于接收前端发送验证码请求时的参数。
 * 位于博客系统的认证模块，是邮箱验证流程的入口数据结构。
 *
 * <p>验证规则：</p>
 * <ul>
 *   <li>email - 必填，必须是有效的邮箱格式</li>
 * </ul>
 *
 * @param email 邮箱地址
 * @author blog-mimo
 */
public record SendCodeRequest(
        @NotBlank @Email String email
) {
}
