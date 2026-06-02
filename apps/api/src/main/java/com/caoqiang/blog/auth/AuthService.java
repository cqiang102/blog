package com.caoqiang.blog.auth;

import com.caoqiang.blog.common.BusinessException;
import com.caoqiang.blog.user.User;
import com.caoqiang.blog.user.UserProfileResponse;
import com.caoqiang.blog.user.UserRepository;
import java.time.Clock;
import java.time.Instant;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {

    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtService jwtService;
    private final RefreshTokenService refreshTokenService;
    private final Clock clock;

    public AuthService(
            UserRepository userRepository,
            PasswordEncoder passwordEncoder,
            JwtService jwtService,
            RefreshTokenService refreshTokenService,
            Clock clock
    ) {
        this.userRepository = userRepository;
        this.passwordEncoder = passwordEncoder;
        this.jwtService = jwtService;
        this.refreshTokenService = refreshTokenService;
        this.clock = clock;
    }

    @Transactional
    public AuthTokenResponse register(RegisterRequest request) {
        String email = EmailNormalizer.normalize(request.email());
        if (userRepository.existsByEmail(email)) {
            throw new BusinessException(HttpStatus.CONFLICT, "邮箱已注册");
        }

        User user = User.register(email, passwordEncoder.encode(request.password()), request.nickname().trim());
        userRepository.save(user);
        return issueTokens(user);
    }

    @Transactional
    public AuthTokenResponse login(LoginRequest request) {
        String email = EmailNormalizer.normalize(request.email());
        User user = userRepository.findByEmail(email)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "邮箱或密码错误"));

        if (!user.isActive() || user.getPasswordHash() == null
                || !passwordEncoder.matches(request.password(), user.getPasswordHash())) {
            throw new BusinessException(HttpStatus.UNAUTHORIZED, "邮箱或密码错误");
        }

        return issueTokens(user);
    }

    @Transactional
    public AuthTokenResponse refresh(RefreshTokenRequest request) {
        String tokenHash = refreshTokenService.hash(request.refreshToken());
        RefreshToken refreshToken = refreshTokenService.findUsable(tokenHash)
                .orElseThrow(() -> new BusinessException(HttpStatus.UNAUTHORIZED, "刷新令牌无效"));

        Instant now = clock.instant();
        if (refreshToken.isExpired(now) || !refreshToken.getUser().isActive()) {
            refreshToken.revoke(now);
            throw new BusinessException(HttpStatus.UNAUTHORIZED, "刷新令牌无效");
        }

        refreshToken.revoke(now);
        return issueTokens(refreshToken.getUser());
    }

    private AuthTokenResponse issueTokens(User user) {
        JwtService.JwtToken accessToken = jwtService.createAccessToken(user);
        RefreshTokenService.RawRefreshToken refreshToken = refreshTokenService.createFor(user);
        return new AuthTokenResponse(
                accessToken.value(),
                refreshToken.value(),
                accessToken.expiresAt(),
                UserProfileResponse.from(user)
        );
    }
}
