package com.caoqiang.blog.auth;

import com.caoqiang.blog.user.User;
import java.util.Collection;
import java.util.Map;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.oauth2.core.user.OAuth2User;

/**
 * GitHub OAuth2 用户模型
 * 封装 GitHub OAuth2 认证后的用户信息，结合 OAuth2 原始数据和本地用户实体。
 * 位于博客系统的认证模块，是 OAuth2 认证流程中的用户表示。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>委托模式 - 委托 OAuth2User 处理原始属性</li>
 *   <li>用户关联 - 关联本地用户实体，提供用户 ID 和角色信息</li>
 *   <li>权限转换 - 将用户角色转换为 Spring Security 的 GrantedAuthority 集合</li>
 *   <li>身份标识 - 使用用户 ID 作为身份标识</li>
 * </ul>
 *
 * <p>与 OAuth2User 的区别：</p>
 * <ul>
 *   <li>OAuth2User 只包含 OAuth2 提供者返回的原始属性</li>
 *   <li>GithubOAuth2User 额外关联了本地用户实体</li>
 *   <li>GithubOAuth2User 提供了基于本地用户角色的权限信息</li>
 * </ul>
 *
 * @author blog-mimo
 */
public class GithubOAuth2User implements OAuth2User {

    /** 委托的 OAuth2User 对象，包含原始 OAuth2 属性 */
    private final OAuth2User delegate;
    /** 关联的本地用户实体 */
    private final User user;

    /**
     * 构造函数
     *
     * @param delegate 委托的 OAuth2User 对象
     * @param user     关联的本地用户实体
     */
    public GithubOAuth2User(OAuth2User delegate, User user) {
        this.delegate = delegate;
        this.user = user;
    }

    /**
     * 获取 OAuth2 属性
     * 委托给原始 OAuth2User 对象，返回 GitHub 返回的用户属性。
     *
     * @return OAuth2 属性 Map
     */
    @Override
    public Map<String, Object> getAttributes() {
        return delegate.getAttributes();
    }

    /**
     * 获取用户权限集合
     * 根据本地用户角色生成 Spring Security 的 GrantedAuthority 集合。
     * 角色名称前会添加 "ROLE_" 前缀，这是 Spring Security 的约定。
     *
     * @return 用户权限集合
     */
    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return AuthorityUtils.createAuthorityList("ROLE_" + user.getRole().name());
    }

    /**
     * 获取用户名称
     * 使用用户 ID 作为身份标识。
     *
     * @return 用户 ID 字符串
     */
    @Override
    public String getName() {
        return user.getId().toString();
    }

    /**
     * 获取关联的本地用户实体
     *
     * @return 用户实体
     */
    public User getUser() {
        return user;
    }
}
