package com.caoqiang.blog.auth;

import com.caoqiang.blog.shared.model.Role;
import java.time.Instant;
import java.util.UUID;

/**
 * JWT 声明记录
 * 封装从 JWT 令牌中解析出的用户声明信息。
 * 位于博客系统的认证模块，是 JWT 令牌的数据载体。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>不可变数据 - 使用 Java Record 实现，所有字段都是 final 的</li>
 *   <li>用户标识 - 包含用户 ID 和邮箱</li>
 *   <li>用户信息 - 包含用户昵称和角色</li>
 *   <li>令牌时效 - 包含令牌过期时间</li>
 * </ul>
 *
 * <p>字段说明：</p>
 * <ul>
 *   <li>userId - 用户唯一标识符（UUID）</li>
 *   <li>email - 用户邮箱地址</li>
 *   <li>nickname - 用户昵称</li>
 *   <li>role - 用户角色（USER 或 ADMIN）</li>
 *   <li>expiresAt - 令牌过期时间</li>
 * </ul>
 *
 * @param userId    用户唯一标识符
 * @param email     用户邮箱地址
 * @param nickname  用户昵称
 * @param role      用户角色
 * @param expiresAt 令牌过期时间
 * @author blog-mimo
 */
public record JwtClaims(UUID userId, String email, String nickname, Role role, Instant expiresAt) {
}
