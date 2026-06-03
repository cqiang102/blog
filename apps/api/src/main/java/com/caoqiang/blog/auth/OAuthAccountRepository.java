package com.caoqiang.blog.auth;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * OAuth 账户仓库接口
 * 提供 OAuth 账户实体的数据库访问方法，继承自 JpaRepository。
 * 位于博客系统的认证模块，是 OAuth 账户数据访问层的核心组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>标准 CRUD 操作 - 继承 JpaRepository 提供的基本数据库操作</li>
 *   <li>自定义查询 - 根据提供者和用户 ID 查找 OAuth 账户</li>
 *   <li>存在性检查 - 检查指定提供者和用户 ID 的账户是否存在</li>
 *   <li>类型安全 - 使用 UUID 作为主键类型</li>
 * </ul>
 *
 * <p>查询方法：</p>
 * <ul>
 *   <li>findByProviderAndProviderUserId - 根据提供者和用户 ID 查找 OAuth 账户</li>
 *   <li>existsByProviderAndProviderUserId - 检查 OAuth 账户是否存在</li>
 * </ul>
 *
 * @author blog-mimo
 */
public interface OAuthAccountRepository extends JpaRepository<OAuthAccount, UUID> {

    /**
     * 根据提供者和用户 ID 查找 OAuth 账户
     * 用于在 OAuth2 登录时查找已关联的账户。
     *
     * @param provider       OAuth 提供者枚举
     * @param providerUserId 第三方平台的用户 ID
     * @return 包含 OAuthAccount 的 Optional，如果不存在则为空
     */
    Optional<OAuthAccount> findByProviderAndProviderUserId(OAuthProvider provider, String providerUserId);

    /**
     * 检查 OAuth 账户是否存在
     * 用于验证指定提供者和用户 ID 的账户是否已关联。
     *
     * @param provider       OAuth 提供者枚举
     * @param providerUserId 第三方平台的用户 ID
     * @return 如果存在返回 true，否则返回 false
     */
    boolean existsByProviderAndProviderUserId(OAuthProvider provider, String providerUserId);
}
