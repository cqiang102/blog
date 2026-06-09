package com.caoqiang.blog.shared.model;

import com.caoqiang.blog.user.domain.model.User;
import java.util.Collection;
import java.util.List;
import java.util.UUID;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.SimpleGrantedAuthority;

/**
 * 已认证用户记录
 * 封装经过认证的用户信息，作为 Spring Security 的 Principal 对象。
 *
 * @param id       用户唯一标识符
 * @param email    用户邮箱地址
 * @param nickname 用户昵称
 * @param role     用户角色
 */
public record AuthenticatedUser(UUID id, String email, String nickname, Role role) {

    /**
     * 从 User 实体创建 AuthenticatedUser
     */
    public static AuthenticatedUser from(User user) {
        return new AuthenticatedUser(user.getId(), user.getEmail(), user.getNickname(), user.getRole());
    }

    /**
     * 获取用户权限集合
     */
    public Collection<? extends GrantedAuthority> authorities() {
        return List.of(new SimpleGrantedAuthority("ROLE_" + role.name()));
    }
}
