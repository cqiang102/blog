package com.caoqiang.blog.auth.application.service;

import com.caoqiang.blog.auth.application.dto.IssuedAuthSession;
import com.caoqiang.blog.shared.exception.BusinessException;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.Base64;
import java.util.List;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import tools.jackson.databind.ObjectMapper;

@Service
public class OAuthLoginCodeService {

    private static final String KEY_PREFIX = "auth:oauth-login:";
    private static final Duration CODE_TTL = Duration.ofMinutes(2);
    private static final DefaultRedisScript<String> CONSUME_SCRIPT =
            new DefaultRedisScript<>("return redis.call('GETDEL', KEYS[1])", String.class);

    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;
    private final SecureRandom secureRandom = new SecureRandom();

    public OAuthLoginCodeService(StringRedisTemplate redisTemplate, ObjectMapper objectMapper) {
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
    }

    public String create(IssuedAuthSession session) {
        byte[] randomBytes = new byte[32];
        secureRandom.nextBytes(randomBytes);
        String code = Base64.getUrlEncoder().withoutPadding().encodeToString(randomBytes);
        try {
            redisTemplate.opsForValue().set(
                    KEY_PREFIX + code,
                    objectMapper.writeValueAsString(session),
                    CODE_TTL
            );
            return code;
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to create OAuth login code", exception);
        }
    }

    public IssuedAuthSession consume(String code) {
        String payload = redisTemplate.execute(CONSUME_SCRIPT, List.of(KEY_PREFIX + code));
        if (payload == null) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "登录凭证无效或已过期");
        }
        try {
            return objectMapper.readValue(payload, IssuedAuthSession.class);
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to read OAuth login code", exception);
        }
    }
}
