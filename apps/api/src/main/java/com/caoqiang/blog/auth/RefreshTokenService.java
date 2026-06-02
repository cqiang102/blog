package com.caoqiang.blog.auth;

import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.user.User;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.Clock;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.util.Base64;
import java.util.Optional;
import org.springframework.stereotype.Service;

@Service
public class RefreshTokenService {

    private static final Base64.Encoder BASE64_URL_ENCODER = Base64.getUrlEncoder().withoutPadding();

    private final RefreshTokenRepository refreshTokenRepository;
    private final BlogProperties blogProperties;
    private final SecureRandom secureRandom = new SecureRandom();
    private final Clock clock;

    public RefreshTokenService(
            RefreshTokenRepository refreshTokenRepository,
            BlogProperties blogProperties,
            Clock clock
    ) {
        this.refreshTokenRepository = refreshTokenRepository;
        this.blogProperties = blogProperties;
        this.clock = clock;
    }

    public RawRefreshToken createFor(User user) {
        String value = randomToken();
        Instant expiresAt = clock.instant().plus(blogProperties.getSecurity().getRefreshTokenDays(), ChronoUnit.DAYS);
        refreshTokenRepository.save(new RefreshToken(user, hash(value), expiresAt));
        return new RawRefreshToken(value, expiresAt);
    }

    public Optional<RefreshToken> findUsable(String tokenHash) {
        return refreshTokenRepository.findByTokenHashAndRevokedAtIsNull(tokenHash);
    }

    public String hash(String token) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return BASE64_URL_ENCODER.encodeToString(digest.digest(token.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to hash refresh token", exception);
        }
    }

    private String randomToken() {
        byte[] token = new byte[32];
        secureRandom.nextBytes(token);
        return BASE64_URL_ENCODER.encodeToString(token);
    }

    public record RawRefreshToken(String value, Instant expiresAt) {
    }
}
