package com.caoqiang.blog.user.domain.model;

import com.caoqiang.blog.shared.domain.model.AggregateRoot;
import com.caoqiang.blog.shared.model.Role;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.PrePersist;
import jakarta.persistence.PreUpdate;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * 用户实体
 * <p>
 * 对应数据库 {@code users} 表，存储用户的基本信息、认证信息和状态。
 * <p>
 * 主要职责：
 * <ul>
 *   <li>用户注册（普通用户和管理员）</li>
 *   <li>个人资料更新</li>
 *   <li>管理员信息更新（包含角色和状态变更）</li>
 *   <li>用户状态管理（激活/禁用）</li>
 * </ul>
 * <p>
 * 使用 UUID 作为主键，邮箱使用 CITEXT 类型实现大小写不敏感匹配。
 */
@Entity
@Table(name = "users")
public class User extends AggregateRoot {

    /** 用户邮箱，唯一且大小写不敏感（CITEXT 类型） */
    @Column(nullable = false, unique = true, columnDefinition = "CITEXT")
    private String email;

    /** 密码哈希值，OAuth 用户可能为空 */
    @Column(name = "password_hash", columnDefinition = "TEXT")
    private String passwordHash;

    /** 用户昵称，最大 80 字符 */
    @Column(nullable = false, length = 80)
    private String nickname;

    /** 头像 URL */
    @Column(name = "avatar_url", columnDefinition = "TEXT")
    private String avatarUrl;

    /** 个人简介 */
    @Column(columnDefinition = "TEXT")
    private String bio;

    /** 个人博客 URL */
    @Column(name = "blog_url", columnDefinition = "TEXT")
    private String blogUrl;

    /** 用户角色：USER 或 ADMIN */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private Role role = Role.USER;

    /** 用户状态：ACTIVE 或 DISABLED */
    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private UserStatus status = UserStatus.ACTIVE;

    /** 创建时间，不可更新 */
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    /** 最后更新时间 */
    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    /** JPA 保护构造函数 */
    protected User() {
    }

    /**
     * 注册普通用户
     *
     * @param email        用户邮箱
     * @param passwordHash 密码哈希值
     * @param nickname     用户昵称
     * @return 新用户实体
     */
    public static User register(String email, String passwordHash, String nickname) {
        User user = new User();
        user.email = email;
        user.passwordHash = passwordHash;
        user.nickname = nickname;
        user.role = Role.USER;
        user.status = UserStatus.ACTIVE;
        return user;
    }

    /**
     * 注册管理员用户
     *
     * @param email        用户邮箱
     * @param passwordHash 密码哈希值
     * @param nickname     用户昵称
     * @return 新管理员用户实体
     */
    public static User admin(String email, String passwordHash, String nickname) {
        User user = register(email, passwordHash, nickname);
        user.role = Role.ADMIN;
        return user;
    }

    /**
     * 实体持久化前的回调，自动设置创建时间和更新时间
     */
    @PrePersist
    void onCreate() {
        Instant now = Instant.now();
        if (createdAt == null) {
            createdAt = now;
        }
        if (updatedAt == null) {
            updatedAt = now;
        }
    }

    /**
     * 实体更新前的回调，自动更新更新时间
     */
    @PreUpdate
    void onUpdate() {
        updatedAt = Instant.now();
    }

    /**
     * 更新用户个人资料
     *
     * @param email     新邮箱
     * @param nickname  新昵称
     * @param avatarUrl 新头像 URL
     * @param bio       新个人简介
     * @param blogUrl   新博客 URL
     */
    public void updateProfile(String email, String nickname, String avatarUrl, String bio, String blogUrl) {
        this.email = email;
        this.nickname = nickname;
        this.avatarUrl = avatarUrl;
        this.bio = bio;
        this.blogUrl = blogUrl;
    }

    /**
     * 应用管理员更新（包含角色和状态变更）
     *
     * @param email     新邮箱
     * @param nickname  新昵称
     * @param avatarUrl 新头像 URL
     * @param bio       新个人简介
     * @param blogUrl   新博客 URL
     * @param role      新角色
     * @param status    新状态
     */
    public void applyAdminUpdate(
            String email,
            String nickname,
            String avatarUrl,
            String bio,
            String blogUrl,
            Role role,
            UserStatus status
    ) {
        updateProfile(email, nickname, avatarUrl, bio, blogUrl);
        this.role = role;
        this.status = status;
    }

    /**
     * 启用管理员权限
     *
     * @param passwordHash 密码哈希值
     * @param nickname     昵称
     */
    public void enableAdmin(String passwordHash, String nickname) {
        this.role = Role.ADMIN;
        this.status = UserStatus.ACTIVE;
        this.passwordHash = passwordHash;
        this.nickname = nickname;
    }

    /**
     * 检查用户是否处于活跃状态
     *
     * @return 如果用户状态为 ACTIVE 则返回 true
     */
    public boolean isActive() {
        return status == UserStatus.ACTIVE;
    }

    public String getEmail() {
        return email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public String getNickname() {
        return nickname;
    }

    public String getAvatarUrl() {
        return avatarUrl;
    }

    public String getBio() {
        return bio;
    }

    public String getBlogUrl() {
        return blogUrl;
    }

    public Role getRole() {
        return role;
    }

    public UserStatus getStatus() {
        return status;
    }

    public Instant getCreatedAt() {
        return createdAt;
    }

    public Instant getUpdatedAt() {
        return updatedAt;
    }

    public void setNickname(String nickname) {
        this.nickname = nickname;
    }

    public void setAvatarUrl(String avatarUrl) {
        this.avatarUrl = avatarUrl;
    }

    public void setBio(String bio) {
        this.bio = bio;
    }

    public void setBlogUrl(String blogUrl) {
        this.blogUrl = blogUrl;
    }

    public void setPasswordHash(String passwordHash) {
        this.passwordHash = passwordHash;
    }
}
