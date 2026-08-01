package com.caoqiang.blog.auth.application.service;

import com.caoqiang.blog.auth.domain.model.RefreshToken;
import com.caoqiang.blog.auth.domain.repository.RefreshTokenRepository;
import com.caoqiang.blog.config.BlogProperties;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.Optional;
import java.util.UUID;
import org.springframework.stereotype.Service;

/**
 * 刷新令牌服务
 * 管理刷新令牌的完整生命周期，包括创建、查找、验证和哈希处理。
 * 位于博客系统的认证模块，是令牌管理的核心组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>令牌创建 - 为用户生成安全的随机刷新令牌</li>
 *   <li>令牌族 - 同一登录链的令牌共享 familyId，支持重放攻击检测</li>
 *   <li>令牌查找 - 根据令牌哈希查找可用的刷新令牌</li>
 *   <li>令牌哈希 - 使用 SHA-256 对令牌进行哈希处理，安全存储</li>
 *   <li>族撤销 - 检测到重放攻击时撤销整个令牌族</li>
 * </ul>
 *
 * @author blog-mimo
 */
@Service
public class RefreshTokenService {

    /** Base64URL 编码器（无填充） */
    private static final Base64.Encoder BASE64_URL_ENCODER =
            Base64.getUrlEncoder().withoutPadding();
    /** 刷新令牌的随机字节长度，32 字节 = 256 位，提供足够的熵以防止暴力猜测 */
    private static final int TOKEN_BYTE_LENGTH = 32;

    /** 刷新令牌仓库，用于数据库操作 */
    private final RefreshTokenRepository refreshTokenRepository;
    /** 博客配置属性，包含令牌有效期等配置 */
    private final BlogProperties blogProperties;
    /** 安全随机数生成器，用于生成随机令牌 */
    private final SecureRandom secureRandom = new SecureRandom();
    /** 时钟，用于获取当前时间，便于测试 */
    private final Clock clock;

    /**
     * 构造函数，注入依赖
     *
     * @param refreshTokenRepository 刷新令牌仓库
     * @param blogProperties         博客配置属性
     * @param clock                  时钟实例
     */
    public RefreshTokenService(
            RefreshTokenRepository refreshTokenRepository, BlogProperties blogProperties, Clock clock) {
        this.refreshTokenRepository = refreshTokenRepository;
        this.blogProperties = blogProperties;
        this.clock = clock;
    }

    /**
     * 为用户创建刷新令牌（新登录链，自动生成 familyId）
     *
     * @param userId 用户 ID
     * @return 包含原始令牌值和过期时间的 RawRefreshToken 记录
     */
    public RawRefreshToken createFor(UUID userId) {
        String value = randomToken();
        Instant expiresAt = clock.instant().plus(blogProperties.getSecurity().getRefreshTokenDays(), ChronoUnit.DAYS);
        refreshTokenRepository.save(new RefreshToken(userId, hash(value), expiresAt));
        return new RawRefreshToken(value, expiresAt);
    }

    /**
     * 在已有令牌族内创建轮换令牌
     *
     * @param userId   用户 ID
     * @param familyId 所属令牌族 ID
     * @return 包含原始令牌值和过期时间的 RawRefreshToken 记录
     */
    public RawRefreshToken createInFamily(UUID userId, UUID familyId) {
        String value = randomToken();
        Instant expiresAt = clock.instant().plus(blogProperties.getSecurity().getRefreshTokenDays(), ChronoUnit.DAYS);
        refreshTokenRepository.save(new RefreshToken(userId, hash(value), expiresAt, familyId));
        return new RawRefreshToken(value, expiresAt);
    }

    /**
     * 查找可用的刷新令牌（未撤销）
     *
     * @param tokenHash 令牌哈希值
     * @return 包含 RefreshToken 的 Optional，如果不存在或已撤销则为空
     */
    public Optional<RefreshToken> findUsable(String tokenHash) {
        return refreshTokenRepository.findByTokenHashAndRevokedAtIsNull(tokenHash);
    }

    /**
     * 根据哈希查找令牌（不论撤销状态），用于重放攻击检测。
     *
     * @param tokenHash 令牌哈希值
     * @return 包含 RefreshToken 的 Optional
     */
    public Optional<RefreshToken> findByHash(String tokenHash) {
        return refreshTokenRepository.findByTokenHash(tokenHash);
    }

    /**
     * 撤销指定令牌族内所有未撤销的令牌。
     *
     * @param familyId 令牌族 ID
     * @return 受影响的行数
     */
    public int revokeFamily(UUID familyId) {
        return refreshTokenRepository.revokeAllByFamilyId(familyId, clock.instant());
    }

    /**
     * 对令牌进行哈希处理
     *
     * @param token 原始令牌字符串
     * @return Base64URL 编码的哈希值
     * @throws IllegalStateException 如果哈希计算失败
     */
    public String hash(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return BASE64_URL_ENCODER.encodeToString(digest.digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException("无法对刷新令牌进行哈希", exception);
        }
    }

    /**
     * 生成随机令牌
     */
    private String randomToken() {
        byte[] token = new byte[TOKEN_BYTE_LENGTH];
        secureRandom.nextBytes(token);
        return BASE64_URL_ENCODER.encodeToString(token);
    }

    /**
     * 原始刷新令牌记录
     *
     * @param value     原始令牌字符串
     * @param expiresAt 过期时间
     */
    public record RawRefreshToken(String value, Instant expiresAt) {}
}
