package com.caoqiang.blog.auth;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.auth.application.dto.IssuedAuthSession;
import com.caoqiang.blog.auth.application.dto.LoginRequest;
import com.caoqiang.blog.auth.application.service.AuthService;
import com.caoqiang.blog.auth.application.service.JwtService;
import com.caoqiang.blog.auth.application.service.RefreshTokenService;
import com.caoqiang.blog.auth.application.service.VerificationService;
import com.caoqiang.blog.auth.domain.model.RefreshToken;
import com.caoqiang.blog.content.application.api.ContentMediaService;
import com.caoqiang.blog.shared.domain.event.DomainEventPublisher;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;

@ExtendWith(MockitoExtension.class)
class AuthServiceTest {

    private static final Instant NOW = Instant.parse("2026-08-01T00:00:00Z");
    private static final Clock FIXED_CLOCK = Clock.fixed(NOW, ZoneOffset.UTC);

    @Mock
    private UserAccountService userAccountService;

    @Mock
    private PasswordEncoder passwordEncoder;

    @Mock
    private JwtService jwtService;

    @Mock
    private RefreshTokenService refreshTokenService;

    @Mock
    private VerificationService verificationService;

    @Mock
    private DomainEventPublisher domainEventPublisher;

    @Mock
    private ContentMediaService contentMediaService;

    private AuthService authService;
    private IdentityUser activeUser;

    @BeforeEach
    void setUp() {
        authService = new AuthService(
                userAccountService,
                passwordEncoder,
                jwtService,
                refreshTokenService,
                verificationService,
                domainEventPublisher,
                contentMediaService,
                FIXED_CLOCK);
        UUID userId = UUID.randomUUID();
        activeUser = new IdentityUser(userId, "user@example.com", "用户", null, null, null, "$2a$hash", Role.USER, true);
    }

    // --- 登录锁定测试 ---

    @Test
    void loginSucceedsWithCorrectCredentials() {
        when(userAccountService.findByEmail("user@example.com")).thenReturn(Optional.of(activeUser));
        when(passwordEncoder.matches("password123", "$2a$hash")).thenReturn(true);
        stubTokenIssuance();

        IssuedAuthSession session = authService.login(new LoginRequest("user@example.com", "password123"));

        assertThat(session).isNotNull();
    }

    @Test
    void loginFailsWithWrongPassword() {
        when(userAccountService.findByEmail("user@example.com")).thenReturn(Optional.of(activeUser));
        when(passwordEncoder.matches("wrong", "$2a$hash")).thenReturn(false);

        assertThatThrownBy(() -> authService.login(new LoginRequest("user@example.com", "wrong")))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).status())
                .isEqualTo(HttpStatus.UNAUTHORIZED);
    }

    @Test
    void loginLocksAccountAfterFiveFailures() {
        when(userAccountService.findByEmail("user@example.com")).thenReturn(Optional.of(activeUser));
        when(passwordEncoder.matches("wrong", "$2a$hash")).thenReturn(false);

        // 5 次失败
        for (int i = 0; i < 5; i++) {
            assertThatThrownBy(() -> authService.login(new LoginRequest("user@example.com", "wrong")))
                    .isInstanceOf(BusinessException.class);
        }

        // 第 6 次应被锁定（429）
        assertThatThrownBy(() -> authService.login(new LoginRequest("user@example.com", "wrong")))
                .isInstanceOf(BusinessException.class)
                .satisfies(e -> {
                    BusinessException ex = (BusinessException) e;
                    assertThat(ex.status()).isEqualTo(HttpStatus.TOO_MANY_REQUESTS);
                    assertThat(ex.getMessage()).contains("登录失败次数过多");
                });
    }

    @Test
    void loginResetsFailureCountOnSuccess() {
        when(userAccountService.findByEmail("user@example.com")).thenReturn(Optional.of(activeUser));
        when(passwordEncoder.matches("wrong", "$2a$hash")).thenReturn(false);
        when(passwordEncoder.matches("correct", "$2a$hash")).thenReturn(true);

        // 3 次失败
        for (int i = 0; i < 3; i++) {
            assertThatThrownBy(() -> authService.login(new LoginRequest("user@example.com", "wrong")))
                    .isInstanceOf(BusinessException.class);
        }

        // 成功登录
        stubTokenIssuance();
        IssuedAuthSession session = authService.login(new LoginRequest("user@example.com", "correct"));
        assertThat(session).isNotNull();

        // 再失败 5 次才锁定（计数已重置）
        when(passwordEncoder.matches("wrong", "$2a$hash")).thenReturn(false);
        for (int i = 0; i < 4; i++) {
            assertThatThrownBy(() -> authService.login(new LoginRequest("user@example.com", "wrong")))
                    .isInstanceOf(BusinessException.class)
                    .satisfies(e -> assertThat(((BusinessException) e).status()).isEqualTo(HttpStatus.UNAUTHORIZED));
        }
    }

    // --- 令牌族撤销测试 ---

    @Test
    void refreshRevokesFamilyWhenReplayedTokenIsDetected() {
        UUID familyId = UUID.randomUUID();
        RefreshToken revokedToken = new RefreshToken(activeUser.id(), "old-hash", NOW.plusSeconds(86400), familyId);
        revokedToken.revoke(NOW.minusSeconds(60)); // 已被撤销

        when(refreshTokenService.hash("replayed-token")).thenReturn("old-hash");
        when(refreshTokenService.findUsable("old-hash")).thenReturn(Optional.empty());
        when(refreshTokenService.findByHash("old-hash")).thenReturn(Optional.of(revokedToken));
        when(refreshTokenService.revokeFamily(familyId)).thenReturn(2);

        assertThatThrownBy(() -> authService.refresh("replayed-token"))
                .isInstanceOf(BusinessException.class)
                .extracting(e -> ((BusinessException) e).status())
                .isEqualTo(HttpStatus.UNAUTHORIZED);

        verify(refreshTokenService).revokeFamily(familyId);
    }

    @Test
    void refreshIssuesTokenInSameFamilyOnNormalRotation() {
        UUID familyId = UUID.randomUUID();
        RefreshToken validToken = new RefreshToken(activeUser.id(), "valid-hash", NOW.plusSeconds(86400), familyId);

        when(refreshTokenService.hash("my-refresh")).thenReturn("valid-hash");
        when(refreshTokenService.findUsable("valid-hash")).thenReturn(Optional.of(validToken));
        when(userAccountService.findActiveById(activeUser.id())).thenReturn(Optional.of(activeUser));
        when(jwtService.createAccessToken(activeUser))
                .thenReturn(new JwtService.JwtToken("jwt", NOW.plusSeconds(1800)));
        when(refreshTokenService.createInFamily(activeUser.id(), familyId))
                .thenReturn(new RefreshTokenService.RawRefreshToken("new-raw", NOW.plusSeconds(86400)));
        when(contentMediaService.resolveUrl(any())).thenReturn(null);

        IssuedAuthSession session = authService.refresh("my-refresh");

        assertThat(session.refreshToken()).isEqualTo("new-raw");
        verify(refreshTokenService).createInFamily(activeUser.id(), familyId);
        verify(refreshTokenService, never()).createFor(any());
    }

    private void stubTokenIssuance() {
        when(jwtService.createAccessToken(any())).thenReturn(new JwtService.JwtToken("jwt", NOW.plusSeconds(1800)));
        when(refreshTokenService.createFor(any(UUID.class)))
                .thenReturn(new RefreshTokenService.RawRefreshToken("raw", NOW.plusSeconds(86400)));
        when(contentMediaService.resolveUrl(any())).thenReturn(null);
    }
}
