package com.caoqiang.blog.auth.service;

import com.caoqiang.blog.auth.entity.RefreshToken;
import com.caoqiang.blog.auth.repository.RefreshTokenRepository;

import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.user.entity.User;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.Optional;
import org.springframework.stereotype.Service;

/**
 * 刷新令牌服务
 * 管理刷新令牌的完整生命周期，包括创建、查找、验证和哈希处理。
 * 位于博客系统的认证模块，是令牌管理的核心组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>令牌创建 - 为用户生成安全的随机刷新令牌</li>
 *   <li>令牌查找 - 根据令牌哈希查找可用的刷新令牌</li>
 *   <li>令牌哈希 - 使用 SHA-256 对令牌进行哈希处理，安全存储</li>
 *   <li>随机生成 - 使用 SecureRandom 生成密码学安全的随机令牌</li>
 * </ul>
 *
 * <p>安全设计：</p>
 * <ul>
 *   <li>数据库中只存储令牌的哈希值，不存储原始令牌</li>
 *   <li>使用 SHA-256 算法进行哈希，确保单向性</li>
 *   <li>使用 SecureRandom 生成随机令牌，确保不可预测性</li>
 *   <li>令牌长度为 32 字节（256 位），提供足够的熵</li>
 * </ul>
 *
 * @author blog-mimo
 */
@Service
public class RefreshTokenService {

    /** Base64URL 编码器（无填充） */
    private static final Base64.Encoder BASE64_URL_ENCODER = Base64.getUrlEncoder().withoutPadding();
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
            RefreshTokenRepository refreshTokenRepository,
            BlogProperties blogProperties,
            Clock clock
    ) {
        this.refreshTokenRepository = refreshTokenRepository;
        this.blogProperties = blogProperties;
        this.clock = clock;
    }

    /**
     * 为用户创建刷新令牌
     * 生成随机令牌，计算哈希值，保存到数据库，并返回原始令牌。
     *
     * @param user 用户实体
     * @return 包含原始令牌值和过期时间的 RawRefreshToken 记录
     */
    public RawRefreshToken createFor(User user) {
        // 生成随机令牌
        String value = randomToken();
        // 计算过期时间：当前时间 + 配置的刷新令牌有效期（天）
        Instant expiresAt = clock.instant().plus(blogProperties.getSecurity().getRefreshTokenDays(), ChronoUnit.DAYS);
        // 保存令牌哈希到数据库（不保存原始令牌）
        refreshTokenRepository.save(new RefreshToken(user, hash(value), expiresAt));
        // 返回原始令牌（客户端需要保存）
        return new RawRefreshToken(value, expiresAt);
    }

    /**
     * 查找可用的刷新令牌
     * 根据令牌哈希查找未撤销的刷新令牌。
     *
     * @param tokenHash 令牌哈希值
     * @return 包含 RefreshToken 的 Optional，如果不存在或已撤销则为空
     */
    public Optional<RefreshToken> findUsable(String tokenHash) {
        return refreshTokenRepository.findByTokenHashAndRevokedAtIsNull(tokenHash);
    }

    /**
     * 对令牌进行哈希处理
     * 使用 SHA-256 算法对令牌进行哈希，用于安全存储和比较。
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
            throw new IllegalStateException("Unable to hash refresh token", exception);
        }
    }

    /**
     * 生成随机令牌
     * 使用 SecureRandom 生成 32 字节的随机令牌，并进行 Base64URL 编码。
     *
     * @return Base64URL 编码的随机令牌字符串
     */
    private String randomToken() {
        byte[] token = new byte[TOKEN_BYTE_LENGTH];
        secureRandom.nextBytes(token);
        return BASE64_URL_ENCODER.encodeToString(token);
    }

    /**
     * 原始刷新令牌记录
     * 包含客户端需要保存的原始令牌值和过期时间。
     *
     * @param value     原始令牌字符串
     * @param expiresAt 过期时间
     */
    public record RawRefreshToken(String value, Instant expiresAt) {
    }
}
