package com.caoqiang.blog.auth.dto;

import com.caoqiang.blog.user.entity.User;
import java.util.Collection;
import java.util.Map;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.security.core.authority.AuthorityUtils;
import org.springframework.security.oauth2.core.user.OAuth2User;

/**
 * GitHub OAuth2 用户模型
 * 封装 GitHub OAuth2 认证后的用户信息，结合 OAuth2 原始数据和本地用户实体。
 */
public class GithubOAuth2User implements OAuth2User {

    private final OAuth2User delegate;
    private final User user;

    public GithubOAuth2User(OAuth2User delegate, User user) {
        this.delegate = delegate;
        this.user = user;
    }

    @Override
    public Map<String, Object> getAttributes() {
        return delegate.getAttributes();
    }

    @Override
    public Collection<? extends GrantedAuthority> getAuthorities() {
        return AuthorityUtils.createAuthorityList("ROLE_" + user.getRole().name());
    }

    @Override
    public String getName() {
        return user.getId().toString();
    }

    public User getUser() {
        return user;
    }
}
