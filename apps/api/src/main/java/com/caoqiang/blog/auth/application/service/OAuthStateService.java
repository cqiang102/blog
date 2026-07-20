package com.caoqiang.blog.auth.application.service;

import com.caoqiang.blog.shared.exception.BusinessException;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.Base64;
import java.util.List;
import java.util.UUID;
import java.util.regex.Pattern;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

/** Issues opaque, browser-bound and single-use OAuth states. */
@Service
public class OAuthStateService {

    private static final String KEY_PREFIX = "auth:oauth-state:";
    private static final Duration STATE_TTL = Duration.ofMinutes(5);
    private static final Pattern OPAQUE_TOKEN = Pattern.compile("[A-Za-z0-9_-]{43}");
    private static final DefaultRedisScript<String> CONSUME_SCRIPT =
            new DefaultRedisScript<>("return redis.call('GETDEL', KEYS[1])", String.class);

    private final StringRedisTemplate redisTemplate;
    private final SecureRandom secureRandom = new SecureRandom();

    public OAuthStateService(StringRedisTemplate redisTemplate) {
        this.redisTemplate = redisTemplate;
    }

    public String createLoginState(String browserId) {
        return create(StateType.LOGIN, null, browserId);
    }

    public String createBindingState(UUID userId, String browserId) {
        return create(StateType.BIND, userId, browserId);
    }

    private String create(StateType type, UUID bindingUserId, String browserId) {
        requireBrowserId(browserId);
        String state = randomToken();
        String payload = type.name() + "\n" + (bindingUserId == null ? "" : bindingUserId) + "\n" + hash(browserId);
        try {
            redisTemplate.opsForValue().set(key(state), payload, STATE_TTL);
            return state;
        } catch (RuntimeException exception) {
            throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "OAuth 登录初始化失败，请稍后重试");
        }
    }

    /** Atomically consumes a state and verifies that it belongs to the initiating browser. */
    public ConsumedState consume(String state, String browserId) {
        if (!isOpaqueToken(state)) {
            throw invalidState();
        }
        requireBrowserId(browserId);

        String payload;
        try {
            payload = redisTemplate.execute(CONSUME_SCRIPT, List.of(key(state)));
        } catch (RuntimeException exception) {
            throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "OAuth state 校验服务暂不可用");
        }
        if (payload == null) {
            throw invalidState();
        }

        String[] parts = payload.split("\n", -1);
        if (parts.length != 3 || !constantTimeEquals(parts[2], hash(browserId))) {
            throw invalidState();
        }
        try {
            StateType type = StateType.valueOf(parts[0]);
            UUID bindingUserId = type == StateType.BIND ? UUID.fromString(parts[1]) : null;
            if (type == StateType.LOGIN && !parts[1].isEmpty()) {
                throw invalidState();
            }
            return new ConsumedState(bindingUserId);
        } catch (IllegalArgumentException exception) {
            throw invalidState();
        }
    }

    private void requireBrowserId(String browserId) {
        if (!isOpaqueToken(browserId)) {
            throw invalidState();
        }
    }

    private boolean isOpaqueToken(String value) {
        return value != null && OPAQUE_TOKEN.matcher(value).matches();
    }

    private String randomToken() {
        byte[] bytes = new byte[32];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
    }

    private String key(String state) {
        return KEY_PREFIX + hash(state);
    }

    private String hash(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(digest);
        } catch (NoSuchAlgorithmException exception) {
            throw new IllegalStateException("SHA-256 is unavailable", exception);
        }
    }

    private boolean constantTimeEquals(String expected, String actual) {
        return MessageDigest.isEqual(
                expected.getBytes(StandardCharsets.UTF_8), actual.getBytes(StandardCharsets.UTF_8));
    }

    private BusinessException invalidState() {
        return new BusinessException(HttpStatus.BAD_REQUEST, "OAuth state 无效或已过期");
    }

    private enum StateType {
        LOGIN,
        BIND
    }

    public record ConsumedState(UUID bindingUserId) {}
}
