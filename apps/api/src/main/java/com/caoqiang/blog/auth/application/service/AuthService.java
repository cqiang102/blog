package com.caoqiang.blog.auth.application.service;

import com.caoqiang.blog.auth.application.dto.IssuedAuthSession;
import com.caoqiang.blog.auth.application.dto.LoginRequest;
import com.caoqiang.blog.auth.application.dto.RegisterRequest;
import com.caoqiang.blog.auth.domain.model.RefreshToken;
import com.caoqiang.blog.auth.event.UserCreatedEvent;
import com.caoqiang.blog.content.application.api.ContentMediaService;
import com.caoqiang.blog.shared.domain.event.DomainEventPublisher;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.util.EmailNormalizer;
import com.caoqiang.blog.shared.util.PasswordPolicy;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import com.caoqiang.blog.user.application.api.UserProfileResponse;
import java.time.Clock;
import java.time.Instant;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 认证服务
 * 处理用户认证的核心业务逻辑，包括注册、登录和令牌刷新。
 * 位于博客系统的认证模块，是认证流程的业务逻辑层。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>用户注册 - 创建新用户账户，验证邮箱唯一性，生成认证令牌</li>
 *   <li>用户登录 - 验证用户凭据，检查账户状态，生成认证令牌</li>
 *   <li>令牌刷新 - 验证刷新令牌有效性，轮换刷新令牌，检测重放攻击并撤销令牌族</li>
 * </ul>
 *
 * @author blog-mimo
 */
@Service
public class AuthService {

    private static final Logger log = LoggerFactory.getLogger(AuthService.class);

    /** 用户仓库，用于访问用户数据 */
    private final UserAccountService userAccountService;
    /** 密码编码器，用于密码加密和验证 */
    private final PasswordEncoder passwordEncoder;
    /** JWT 服务，用于创建访问令牌 */
    private final JwtService jwtService;
    /** 刷新令牌服务，用于管理刷新令牌生命周期 */
    private final RefreshTokenService refreshTokenService;
    /** 验证码服务，用于注册时校验邮箱验证码 */
    private final VerificationService verificationService;
    /** 领域事件发布器 */
    private final DomainEventPublisher domainEventPublisher;
    /** 媒体服务，用于统一头像 URL 解析 */
    private final ContentMediaService contentMediaService;
    /** 时钟，用于获取当前时间，便于测试 */
    private final Clock clock;

    public AuthService(
            UserAccountService userAccountService,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            RefreshTokenService refreshTokenService,
            VerificationService verificationService,
            DomainEventPublisher domainEventPublisher,
            ContentMediaService contentMediaService,
            Clock clock) {
        this.userAccountService = userAccountService;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.refreshTokenService = refreshTokenService;
        this.verificationService = verificationService;
        this.domainEventPublisher = domainEventPublisher;
        this.contentMediaService = contentMediaService;
        this.clock = clock;
    }

    @Transactional
    public IssuedAuthSession register(RegisterRequest request) {
        String email = EmailNormalizer.normalize(request.email());
        verificationService.verify(email, request.code());
        if (userAccountService.existsByEmail(email)) {
            throw new BusinessException(HttpStatus.CONFLICT, "邮箱已注册");
        }
        PasswordPolicy.validate(request.password());
        IdentityUser user = userAccountService.registerLocal(
                email,
                passwordEncoder.encode(request.password()),
                request.nickname().trim());
        domainEventPublisher.publishEvent(new UserCreatedEvent(user.id(), user.email(), user.nickname()));
        return issueTokens(user);
    }

    @Transactional
    public IssuedAuthSession login(LoginRequest request) {
        String email = EmailNormalizer.normalize(request.email());
        IdentityUser user = userAccountService
                .findByEmail(email)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "邮箱或密码错误"));
        if (!user.active()
                || user.passwordHash() == null
                || !passwordEncoder.matches(request.password(), user.passwordHash())) {
            throw new BusinessException(HttpStatus.UNAUTHORIZED, "邮箱或密码错误");
        }
        return issueTokens(user);
    }

    /**
     * 刷新令牌。
     * <p>
     * 实现令牌轮换 + 重放攻击检测：
     * <ul>
     *   <li>正常路径：找到未撤销令牌 → 撤销 → 在同一族内签发新令牌</li>
     *   <li>重放检测：令牌已撤销但仍被提交 → 撤销整个令牌族 → 拒绝请求</li>
     * </ul>
     */
    @Transactional
    public IssuedAuthSession refresh(String rawRefreshToken) {
        String tokenHash = refreshTokenService.hash(rawRefreshToken);

        // 尝试查找可用的（未撤销的）令牌
        var usableToken = refreshTokenService.findUsable(tokenHash);
        if (usableToken.isEmpty()) {
            // 重放攻击检测：令牌存在但已被撤销，说明有人试图重用旧令牌
            refreshTokenService.findByHash(tokenHash).ifPresent(revokedToken -> {
                if (revokedToken.isRevoked() && revokedToken.getFamilyId() != null) {
                    int revoked = refreshTokenService.revokeFamily(revokedToken.getFamilyId());
                    log.warn(
                            "Refresh token replay detected: userId={}, familyId={}, revoked {} tokens",
                            revokedToken.getUserId(),
                            revokedToken.getFamilyId(),
                            revoked);
                }
            });
            throw new BusinessException(HttpStatus.UNAUTHORIZED, "刷新令牌无效");
        }

        RefreshToken refreshToken = usableToken.get();
        Instant now = clock.instant();
        IdentityUser user =
                userAccountService.findActiveById(refreshToken.getUserId()).orElse(null);
        if (refreshToken.isExpired(now) || user == null) {
            refreshToken.revoke(now);
            throw new BusinessException(HttpStatus.UNAUTHORIZED, "刷新令牌无效");
        }

        // 撤销当前令牌，在同一族内签发新令牌（保持链路可追溯）
        refreshToken.revoke(now);
        return issueTokensInFamily(user, refreshToken.getFamilyId());
    }

    /** 撤销当前浏览器会话持有的刷新令牌。重复登出保持幂等。 */
    @Transactional
    public void revokeRefreshToken(String rawRefreshToken) {
        String tokenHash = refreshTokenService.hash(rawRefreshToken);
        refreshTokenService.findUsable(tokenHash).ifPresent(token -> token.revoke(clock.instant()));
    }

    /**
     * 为用户生成令牌对（新登录链）
     */
    private IssuedAuthSession issueTokens(IdentityUser user) {
        JwtService.JwtToken accessToken = jwtService.createAccessToken(user);
        RefreshTokenService.RawRefreshToken refreshToken = refreshTokenService.createFor(user.id());
        return new IssuedAuthSession(
                accessToken.value(),
                refreshToken.value(),
                accessToken.expiresAt(),
                UserProfileResponse.from(user, contentMediaService.resolveUrl(user.avatarUrl())));
    }

    /**
     * 在已有令牌族内为用户生成令牌对（轮换）
     */
    private IssuedAuthSession issueTokensInFamily(IdentityUser user, java.util.UUID familyId) {
        JwtService.JwtToken accessToken = jwtService.createAccessToken(user);
        RefreshTokenService.RawRefreshToken refreshToken = familyId != null
                ? refreshTokenService.createInFamily(user.id(), familyId)
                : refreshTokenService.createFor(user.id());
        return new IssuedAuthSession(
                accessToken.value(),
                refreshToken.value(),
                accessToken.expiresAt(),
                UserProfileResponse.from(user, contentMediaService.resolveUrl(user.avatarUrl())));
    }
}
