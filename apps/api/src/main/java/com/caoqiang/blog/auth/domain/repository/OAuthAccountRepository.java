package com.caoqiang.blog.auth.domain.repository;

import com.caoqiang.blog.auth.domain.model.OAuthAccount;
import com.caoqiang.blog.auth.domain.model.OAuthProvider;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * OAuth 账户仓库接口
 * 提供 OAuth 账户实体的数据库访问方法，继承自 JpaRepository。
 *
 * @author blog-mimo
 */
public interface OAuthAccountRepository extends JpaRepository<OAuthAccount, UUID> {

    /**
     * 根据提供者和用户 ID 查找 OAuth 账户
     */
    Optional<OAuthAccount> findByProviderAndProviderUserId(OAuthProvider provider, String providerUserId);

    /**
     * 检查 OAuth 账户是否存在
     */
    boolean existsByProviderAndProviderUserId(OAuthProvider provider, String providerUserId);

    /**
     * 根据用户 ID 查找所有 OAuth 账户关联
     *
     * @param userId 用户 ID
     * @return 该用户绑定的所有 OAuth 账户列表
     */
    List<OAuthAccount> findByUserId(UUID userId);

    /**
     * 根据用户 ID 和提供者查找 OAuth 账户
     *
     * @param userId   用户 ID
     * @param provider OAuth 提供者
     * @return 包含 OAuthAccount 的 Optional
     */
    Optional<OAuthAccount> findByUserIdAndProvider(UUID userId, OAuthProvider provider);

    /**
     * 根据用户 ID 和提供者删除 OAuth 账户
     *
     * @param userId   用户 ID
     * @param provider OAuth 提供者
     */
    void deleteByUserIdAndProvider(UUID userId, OAuthProvider provider);
}
