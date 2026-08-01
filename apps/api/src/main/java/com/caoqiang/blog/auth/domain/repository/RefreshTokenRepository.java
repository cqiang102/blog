package com.caoqiang.blog.auth.domain.repository;

import com.caoqiang.blog.auth.domain.model.RefreshToken;
import jakarta.persistence.LockModeType;
import java.time.Instant;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Lock;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

/**
 * 刷新令牌仓库接口
 * 提供刷新令牌实体的数据库访问方法，继承自 JpaRepository。
 * 位于博客系统的认证模块，是刷新令牌数据访问层的核心组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>标准 CRUD 操作 - 继承 JpaRepository 提供的基本数据库操作</li>
 *   <li>自定义查询 - 根据令牌哈希查找未撤销的刷新令牌</li>
 *   <li>令牌族撤销 - 检测到重放攻击时撤销整个令牌族</li>
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
    @Lock(LockModeType.PESSIMISTIC_WRITE)
    Optional<RefreshToken> findByTokenHashAndRevokedAtIsNull(String tokenHash);

    /**
     * 根据令牌哈希查找令牌（不论撤销状态），用于重放攻击检测。
     *
     * @param tokenHash 令牌的 SHA-256 哈希值
     * @return 包含 RefreshToken 的 Optional
     */
    Optional<RefreshToken> findByTokenHash(String tokenHash);

    /**
     * 撤销指定令牌族内所有未撤销的令牌。
     * 当检测到已撤销令牌被重放时调用，使攻击者持有的后续令牌全部失效。
     *
     * @param familyId  令牌族 ID
     * @param revokedAt 撤销时间
     * @return 受影响的行数
     */
    @Modifying
    @Query("update RefreshToken t set t.revokedAt = :revokedAt where t.familyId = :familyId and t.revokedAt is null")
    int revokeAllByFamilyId(@Param("familyId") UUID familyId, @Param("revokedAt") Instant revokedAt);
}
