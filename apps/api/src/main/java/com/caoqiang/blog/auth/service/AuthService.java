package com.caoqiang.blog.auth.service;

import com.caoqiang.blog.auth.dto.AuthTokenResponse;
import com.caoqiang.blog.auth.dto.JwtClaims;
import com.caoqiang.blog.auth.dto.LoginRequest;
import com.caoqiang.blog.auth.dto.RefreshTokenRequest;
import com.caoqiang.blog.auth.dto.RegisterRequest;
import com.caoqiang.blog.auth.dto.SendCodeRequest;
import com.caoqiang.blog.auth.entity.OAuthAccount;
import com.caoqiang.blog.auth.entity.RefreshToken;
import com.caoqiang.blog.auth.entity.VerificationCode;
import com.caoqiang.blog.auth.enums.OAuthProvider;
import com.caoqiang.blog.auth.repository.OAuthAccountRepository;
import com.caoqiang.blog.auth.repository.RefreshTokenRepository;
import com.caoqiang.blog.auth.repository.VerificationCodeRepository;

import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.user.entity.User;
import com.caoqiang.blog.user.dto.UserProfileResponse;
import com.caoqiang.blog.user.repository.UserRepository;
import java.time.Clock;
import java.time.Instant;
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
 *   <li>令牌刷新 - 验证刷新令牌有效性，轮换刷新令牌，生成新的访问令牌</li>
 * </ul>
 *
 * <p>事务管理：所有公共方法都在事务中执行，确保数据一致性。</p>
 *
 * @author blog-mimo
 */
@Service
public class AuthService {

    /** 用户仓库，用于访问用户数据 */
    private final UserRepository userRepository;
    /** 密码编码器，用于密码加密和验证 */
    private final PasswordEncoder passwordEncoder;
    /** JWT 服务，用于创建访问令牌 */
    private final JwtService jwtService;
    /** 刷新令牌服务，用于管理刷新令牌生命周期 */
    private final RefreshTokenService refreshTokenService;
    /** 验证码服务，用于注册时校验邮箱验证码 */
    private final VerificationService verificationService;
    /** 时钟，用于获取当前时间，便于测试 */
    private final Clock clock;

    /**
     * 构造函数，注入所有依赖
     *
     * @param userRepository        用户仓库
     * @param passwordEncoder       密码编码器
     * @param jwtService            JWT 服务
     * @param refreshTokenService   刷新令牌服务
     * @param verificationService   验证码服务
     * @param clock                 时钟实例
     */
    public AuthService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            RefreshTokenService refreshTokenService,
            VerificationService verificationService,
            Clock clock
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.refreshTokenService = refreshTokenService;
        this.verificationService = verificationService;
        this.clock = clock;
    }

    /**
     * 用户注册
     * 创建新用户账户，验证邮箱唯一性，生成并返回认证令牌。
     *
     * @param request 注册请求，包含邮箱、密码、昵称和验证码
     * @return 包含访问令牌、刷新令牌和用户信息的认证令牌响应
     * @throws BusinessException 如果邮箱已注册（HTTP 409 CONFLICT）或验证码无效
     */
    @Transactional
    public AuthTokenResponse register(RegisterRequest request) {
        // 规范化邮箱地址（转小写、去除空白）
        String email = EmailNormalizer.normalize(request.email());

        // 校验验证码
        verificationService.verify(email, request.code());

        // 检查邮箱是否已被注册
        if (userRepository.existsByEmail(email)) {
            throw new BusinessException(HttpStatus.CONFLICT, "邮箱已注册");
        }

        // 创建用户实体，密码使用 BCrypt 加密
        User user = User.register(email, passwordEncoder.encode(request.password()), request.nickname().trim());
        userRepository.save(user);
        // 生成访问令牌和刷新令牌
        return issueTokens(user);
    }

    /**
     * 用户登录
     * 验证用户凭据，检查账户状态，生成并返回认证令牌。
     *
     * @param request 登录请求，包含邮箱和密码
     * @return 包含访问令牌、刷新令牌和用户信息的认证令牌响应
     * @throws BusinessException 如果邮箱不存在、密码错误或账户已禁用（HTTP 401 UNAUTHORIZED）
     */
    @Transactional
    public AuthTokenResponse login(LoginRequest request) {
        // 规范化邮箱地址
        String email = EmailNormalizer.normalize(request.email());
        // 查找用户，不存在则抛出异常
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "邮箱或密码错误"));

        // 验证用户状态和密码：账户必须激活、必须有密码哈希、密码必须匹配
        if (!user.isActive() || user.getPasswordHash() == null
                || !passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new BusinessException(HttpStatus.UNAUTHORIZED, "邮箱或密码错误");
        }

        // 生成访问令牌和刷新令牌
        return issueTokens(user);
    }

    /**
     * 刷新令牌
     * 验证刷新令牌有效性，轮换刷新令牌（旧令牌失效），生成新的访问令牌。
     *
     * @param request 刷新令牌请求，包含刷新令牌
     * @return 包含新访问令牌、新刷新令牌和用户信息的认证令牌响应
     * @throws BusinessException 如果刷新令牌无效、已过期或用户账户已禁用（HTTP 401 UNAUTHORIZED）
     */
    @Transactional
    public AuthTokenResponse refresh(RefreshTokenRequest request) {
        // 计算刷新令牌的哈希值，用于数据库查询
        String tokenHash = refreshTokenService.hash(request.refreshToken());
        // 查找可用的刷新令牌
        RefreshToken refreshToken = refreshTokenService.findUsable(tokenHash)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "刷新令牌无效"));

        Instant now = clock.instant();
        // 检查令牌是否过期或用户是否激活
        if (refreshToken.isExpired(now) || !refreshToken.getUser().isActive()) {
            refreshToken.revoke(now);
            throw new BusinessException(HttpStatus.UNAUTHORIZED, "刷新令牌无效");
        }

        // 撤销当前刷新令牌（实现令牌轮换，防止重放攻击）
        refreshToken.revoke(now);
        // 为用户生成新的令牌对
        return issueTokens(refreshToken.getUser());
    }

    /**
     * 为用户生成令牌对
     * 创建访问令牌和刷新令牌，并组装成认证令牌响应。
     *
     * @param user 用户实体
     * @return 包含访问令牌、刷新令牌、过期时间和用户信息的认证令牌响应
     */
    private AuthTokenResponse issueTokens(User user) {
        // 创建 JWT 访问令牌
        JwtService.JwtToken accessToken = jwtService.createAccessToken(user);
        // 创建刷新令牌
        RefreshTokenService.RawRefreshToken refreshToken = refreshTokenService.createFor(user);
        // 组装响应，包含用户资料信息
        return new AuthTokenResponse(
                accessToken.value(),
                refreshToken.value(),
                accessToken.expiresAt(),
                UserProfileResponse.from(user)
        );
    }
}
