package com.caoqiang.blog.auth;

import com.caoqiang.blog.user.User;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

/**
 * 已认证用户记录
 * 封装经过认证的用户信息，作为 Spring Security 的 Principal 对象。
 * 位于博客系统的认证模块，是用户身份的内存表示。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>不可变数据 - 使用 Java Record 实现，所有字段都是 final 的</li>
 *   <li>用户标识 - 包含用户 ID、邮箱和昵称</li>
 *   <li>角色信息 - 包含用户角色，用于权限控制</li>
 *   <li>权限转换 - 将角色转换为 Spring Security 的 GrantedAuthority 集合</li>
 * </ul>
 *
 * <p>与 User 实体的区别：</p>
 * <ul>
 *   <li>AuthenticatedUser 是轻量级的，只包含认证和授权所需的字段</li>
 *   <li>User 实体包含完整的用户信息，包括密码哈希等敏感数据</li>
 *   <li>AuthenticatedUser 用于安全上下文，User 用于数据库操作</li>
 * </ul>
 *
 * @param id       用户唯一标识符
 * @param email    用户邮箱地址
 * @param nickname 用户昵称
 * @param role     用户角色
 * @author blog-mimo
 */
public record AuthenticatedUser(UUID id, String email, String nickname, Role role) {

    /**
     * 从 User 实体创建 AuthenticatedUser
     * 提取 User 实体中的关键字段，创建轻量级的认证用户对象。
     *
     * @param user User 实体
     * @return AuthenticatedUser 记录
     */
    public static AuthenticatedUser from(User user) {
        return new AuthenticatedUser(user.getId(), user.getEmail(), user.getNickname(), user.getRole());
    }

    /**
     * 获取用户权限集合
     * 将用户角色转换为 Spring Security 的 GrantedAuthority 集合。
     * 角色名称前会添加 "ROLE_" 前缀，这是 Spring Security 的约定。
     *
     * @return 用户权限集合
     */
    public Collection<? extends GrantedAuthority> authorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + role.name()));
    }
}
