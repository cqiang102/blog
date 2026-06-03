package com.caoqiang.blog.auth;

import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.user.User;
import tools.jackson.core.JacksonException;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.time.Clock;
import java.time.Instant;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.UUID;
import javax.crypto.Mac;
import javax.crypto.spec.SecretKeySpec;
import org.springframework.stereotype.Service;
import org.springframework.util.StringUtils;

/**
 * JWT 服务
 * 负责 JWT（JSON Web Token）的创建和验证，使用 HMAC-SHA256 算法进行签名。
 * 位于博客系统的认证模块，是令牌管理的核心组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>访问令牌创建 - 生成包含用户信息的 JWT 访问令牌</li>
 *   <li>访问令牌解析 - 验证 JWT 签名和有效期，提取用户声明</li>
 *   <li>HMAC-SHA256 签名 - 使用共享密钥对 JWT 进行签名和验证</li>
 *   <li>Base64URL 编码 - 符合 JWT 规范的编码方式</li>
 * </ul>
 *
 * <p>JWT 结构：Header.Payload.Signature</p>
 * <ul>
 *   <li>Header: 包含算法类型（HS256）和令牌类型（JWT）</li>
 *   <li>Payload: 包含用户 ID、邮箱、昵称、角色、签发时间和过期时间</li>
 *   <li>Signature: 使用 HMAC-SHA256 对 Header 和 Payload 的签名</li>
 * </ul>
 *
 * @author blog-mimo
 */
@Service
public class JwtService {

    /** HMAC-SHA256 算法标识 */
    private static final String HMAC_ALGORITHM = "HmacSHA256";
    /** Base64URL 编码器（无填充） */
    private static final Base64.Encoder BASE64_URL_ENCODER = Base64.getUrlEncoder().withoutPadding();
    /** Base64URL 解码器 */
    private static final Base64.Decoder BASE64_URL_DECODER = Base64.getUrlDecoder();

    /** JSON 对象映射器，用于序列化和反序列化 JWT 头部和载荷 */
    private final ObjectMapper objectMapper;
    /** 博客配置属性，包含 JWT 密钥和令牌有效期等配置 */
    private final BlogProperties blogProperties;
    /** 时钟，用于获取当前时间，便于测试 */
    private final Clock clock;

    /**
     * 构造函数，注入依赖
     *
     * @param blogProperties 博客配置属性
     * @param clock          时钟实例
     */
    public JwtService(BlogProperties blogProperties, Clock clock) {
        this.objectMapper = new ObjectMapper();
        this.blogProperties = blogProperties;
        this.clock = clock;
    }

    /**
     * 创建访问令牌
     * 为指定用户生成 JWT 访问令牌，包含用户信息和有效期。
     *
     * @param user 用户实体
     * @return 包含 JWT 值和过期时间的 JwtToken 记录
     */
    public JwtToken createAccessToken(User user) {
        Instant issuedAt = clock.instant();
        // 计算过期时间：当前时间 + 配置的访问令牌有效期（分钟）
        Instant expiresAt = issuedAt.plusSeconds(blogProperties.getSecurity().getAccessTokenMinutes() * 60L);

        // 构建 JWT 头部
        Map<String, Object> header = new LinkedHashMap<>();
        header.put("alg", "HS256");
        header.put("typ", "JWT");

        // 构建 JWT 载荷，包含标准声明和自定义声明
        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("iss", "personal-blog-api");  // 签发者
        payload.put("sub", user.getId().toString());  // 主题（用户 ID）
        payload.put("email", user.getEmail());  // 用户邮箱
        payload.put("nickname", user.getNickname());  // 用户昵称
        payload.put("role", user.getRole().name());  // 用户角色
        payload.put("iat", issuedAt.getEpochSecond());  // 签发时间
        payload.put("exp", expiresAt.getEpochSecond());  // 过期时间

        // 构建签名输入：Base64URL(Header) + "." + Base64URL(Payload)
        String signingInput = encodeJson(header) + "." + encodeJson(payload);
        // 拼接完整 JWT：签名输入 + "." + 签名
        return new JwtToken(signingInput + "." + sign(signingInput), expiresAt);
    }

    /**
     * 解析访问令牌
     * 验证 JWT 签名和有效期，提取用户声明信息。
     *
     * @param token JWT 访问令牌字符串
     * @return 包含用户声明的 JwtClaims 记录
     * @throws IllegalArgumentException 如果令牌为空、格式无效、签名无效、算法不支持或已过期
     */
    public JwtClaims parseAccessToken(String token) {
        // 验证令牌非空
        if (!StringUtils.hasText(token)) {
            throw new IllegalArgumentException("JWT is blank");
        }

        // 分割 JWT 为三部分：头部、载荷、签名
        String[] parts = token.split("\\.");
        if (parts.length != 3) {
            throw new IllegalArgumentException("JWT must have three parts");
        }

        // 验证签名：使用相同密钥计算期望签名，与实际签名进行时间常数比较
        String signingInput = parts[0] + "." + parts[1];
        byte[] expectedSignature = signBytes(signingInput);
        byte[] actualSignature = BASE64_URL_DECODER.decode(parts[2]);
        if (!MessageDigest.isEqual(expectedSignature, actualSignature)) {
            throw new IllegalArgumentException("JWT signature is invalid");
        }

        try {
            // 解析并验证头部
            JsonNode header = objectMapper.readTree(BASE64_URL_DECODER.decode(parts[0]));
            if (!"HS256".equals(header.path("alg").asText())) {
                throw new IllegalArgumentException("JWT algorithm is unsupported");
            }

            // 解析载荷
            JsonNode payload = objectMapper.readTree(BASE64_URL_DECODER.decode(parts[1]));
            // 验证令牌是否过期
            Instant expiresAt = Instant.ofEpochSecond(payload.path("exp").asLong());
            if (!expiresAt.isAfter(clock.instant())) {
                throw new IllegalArgumentException("JWT is expired");
            }

            // 提取用户声明
            return new JwtClaims(
                    UUID.fromString(payload.path("sub").asText()),
                    payload.path("email").asText(),
                    payload.path("nickname").asText(),
                    Role.valueOf(payload.path("role").asText()),
                    expiresAt
            );
        } catch (JacksonException exception) {
            throw new IllegalArgumentException("JWT payload is invalid", exception);
        }
    }

    /**
     * 将 Map 编码为 Base64URL 字符串
     *
     * @param value 要编码的 Map
     * @return Base64URL 编码的字符串
     * @throws IllegalStateException 如果序列化失败
     */
    private String encodeJson(Map<String, Object> value) {
        try {
            return BASE64_URL_ENCODER.encodeToString(objectMapper.writeValueAsBytes(value));
        } catch (JacksonException exception) {
            throw new IllegalStateException("Unable to serialize JWT", exception);
        }
    }

    /**
     * 对签名输入进行签名并编码为 Base64URL 字符串
     *
     * @param signingInput 签名输入字符串
     * @return Base64URL 编码的签名
     */
    private String sign(String signingInput) {
        return BASE64_URL_ENCODER.encodeToString(signBytes(signingInput));
    }

    /**
     * 对签名输入进行 HMAC-SHA256 签名
     *
     * @param signingInput 签名输入字符串
     * @return 签名的字节数组
     * @throws IllegalStateException 如果签名失败
     */
    private byte[] signBytes(String signingInput) {
        try {
            Mac mac = Mac.getInstance(HMAC_ALGORITHM);
            mac.init(new SecretKeySpec(jwtSecret().getBytes(StandardCharsets.UTF_8), HMAC_ALGORITHM));
            return mac.doFinal(signingInput.getBytes(StandardCharsets.UTF_8));
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to sign JWT", exception);
        }
    }

    /**
     * 获取 JWT 密钥
     *
     * @return JWT 密钥字符串
     * @throws IllegalStateException 如果密钥未配置或为空
     */
    private String jwtSecret() {
        String secret = blogProperties.getSecurity().getJwtSecret();
        if (!StringUtils.hasText(secret)) {
            throw new IllegalStateException("blog.security.jwt-secret must not be blank");
        }
        return secret;
    }

    /**
     * JWT 令牌记录
     * 包含 JWT 值和过期时间。
     *
     * @param value      JWT 令牌字符串
     * @param expiresAt  过期时间
     */
    public record JwtToken(String value, Instant expiresAt) {
    }
}
