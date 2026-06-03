package com.caoqiang.blog.auth;

import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 刷新令牌仓库接口
 * 提供刷新令牌实体的数据库访问方法，继承自 JpaRepository。
 * 位于博客系统的认证模块，是刷新令牌数据访问层的核心组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>标准 CRUD 操作 - 继承 JpaRepository 提供的基本数据库操作</li>
 *   <li>自定义查询 - 根据令牌哈希查找未撤销的刷新令牌</li>
 *   <li>类型安全 - 使用 UUID 作为主键类型</li>
 * </ul>
 *
 * <p>查询方法：</p>
 * <ul>
 *   <li>findByTokenHashAndRevokedAtIsNull - 根据令牌哈希查找未撤销的令牌</li>
 * </ul>
 *
 * @author blog-mimo
 */
public interface RefreshTokenRepository extends JpaRepository<RefreshToken, UUID> {

    /**
     * 根据令牌哈希查找未撤销的刷新令牌
     * 用于验证刷新令牌的有效性，只返回未撤销的令牌。
     *
     * @param tokenHash 令牌的 SHA-256 哈希值
     * @return 包含 RefreshToken 的 Optional，如果不存在或已撤销则为空
     */
    Optional<RefreshToken> findByTokenHashAndRevokedAtIsNull(String tokenHash);
}
