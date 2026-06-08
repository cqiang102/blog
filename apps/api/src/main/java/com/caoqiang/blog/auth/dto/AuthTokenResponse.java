package com.caoqiang.blog.auth.dto;

import com.caoqiang.blog.user.dto.UserProfileResponse;
import java.time.Instant;

/**
 * 认证令牌响应 DTO
 * 封装认证成功后返回的令牌信息和用户资料。
 * 位于博客系统的认证模块，是认证流程的响应数据载体。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>不可变数据 - 使用 Java Record 实现，所有字段都是 final 的</li>
 *   <li>令牌信息 - 包含访问令牌、刷新令牌和过期时间</li>
 *   <li>用户信息 - 包含用户资料信息</li>
 *   <li>JSON 序列化 - 可以直接序列化为 JSON 响应</li>
 * </ul>
 *
 * <p>字段说明：</p>
 * <ul>
 *   <li>accessToken - JWT 访问令牌，用于 API 认证</li>
 *   <li>refreshToken - 刷新令牌，用于获取新的访问令牌</li>
 *   <li>expiresAt - 访问令牌的过期时间</li>
 *   <li>user - 用户资料信息</li>
 * </ul>
 *
 * <p>使用场景：</p>
 * <ul>
 *   <li>用户注册 - 注册成功后返回令牌和用户信息</li>
 *   <li>用户登录 - 登录成功后返回令牌和用户信息</li>
 *   <li>令牌刷新 - 刷新成功后返回新的令牌和用户信息</li>
 *   <li>OAuth2 登录 - OAuth2 登录成功后返回令牌和用户信息</li>
 * </ul>
 *
 * @param accessToken  JWT 访问令牌
 * @param refreshToken 刷新令牌
 * @param expiresAt    访问令牌的过期时间
 * @param user         用户资料信息
 * @author blog-mimo
 */
public record AuthTokenResponse(
        /** JWT 访问令牌，用于 API 认证 */
        String accessToken,
        /** 刷新令牌，用于获取新的访问令牌 */
        String refreshToken,
        /** 访问令牌的过期时间 */
        Instant expiresAt,
        /** 用户资料信息 */
        UserProfileResponse user
) {
}
