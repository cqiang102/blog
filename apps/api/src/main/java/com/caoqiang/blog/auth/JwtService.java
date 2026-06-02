package com.caoqiang.blog.auth;

import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.user.User;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
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

@Service
public class JwtService {

    private static final String HMAC_ALGORITHM = "HmacSHA256";
    private static final Base64.Encoder BASE64_URL_ENCODER = Base64.getUrlEncoder().withoutPadding();
    private static final Base64.Decoder BASE64_URL_DECODER = Base64.getUrlDecoder();

    private final ObjectMapper objectMapper;
    private final BlogProperties blogProperties;
    private final Clock clock;

    public JwtService(BlogProperties blogProperties, Clock clock) {
        this.objectMapper = new ObjectMapper();
        this.blogProperties = blogProperties;
        this.clock = clock;
    }

    public JwtToken createAccessToken(User user) {
        Instant issuedAt = clock.instant();
        Instant expiresAt = issuedAt.plusSeconds(blogProperties.getSecurity().getAccessTokenMinutes() * 60L);

        Map<String, Object> header = new LinkedHashMap<>();
        header.put("alg", "HS256");
        header.put("typ", "JWT");

        Map<String, Object> payload = new LinkedHashMap<>();
        payload.put("iss", "personal-blog-api");
        payload.put("sub", user.getId().toString());
        payload.put("email", user.getEmail());
        payload.put("nickname", user.getNickname());
        payload.put("role", user.getRole().name());
        payload.put("iat", issuedAt.getEpochSecond());
        payload.put("exp", expiresAt.getEpochSecond());

        String signingInput = encodeJson(header) + "." + encodeJson(payload);
        return new JwtToken(signingInput + "." + sign(signingInput), expiresAt);
    }

    public JwtClaims parseAccessToken(String token) {
        if (!StringUtils.hasText(token)) {
            throw new IllegalArgumentException("JWT is blank");
        }

        String[] parts = token.split("\\.");
        if (parts.length != 3) {
            throw new IllegalArgumentException("JWT must have three parts");
        }

        String signingInput = parts[0] + "." + parts[1];
        byte[] expectedSignature = signBytes(signingInput);
        byte[] actualSignature = BASE64_URL_DECODER.decode(parts[2]);
        if (!MessageDigest.isEqual(expectedSignature, actualSignature)) {
            throw new IllegalArgumentException("JWT signature is invalid");
        }

        try {
            JsonNode header = objectMapper.readTree(BASE64_URL_DECODER.decode(parts[0]));
            if (!"HS256".equals(header.path("alg").asText())) {
                throw new IllegalArgumentException("JWT algorithm is unsupported");
            }

            JsonNode payload = objectMapper.readTree(BASE64_URL_DECODER.decode(parts[1]));
            Instant expiresAt = Instant.ofEpochSecond(payload.path("exp").asLong());
            if (!expiresAt.isAfter(clock.instant())) {
                throw new IllegalArgumentException("JWT is expired");
            }

            return new JwtClaims(
                    UUID.fromString(payload.path("sub").asText()),
                    payload.path("email").asText(),
                    payload.path("nickname").asText(),
                    Role.valueOf(payload.path("role").asText()),
                    expiresAt
            );
        } catch (IOException exception) {
            throw new IllegalArgumentException("JWT payload is invalid", exception);
        }
    }

    private String encodeJson(Map<String, Object> value) {
        try {
            return BASE64_URL_ENCODER.encodeToString(objectMapper.writeValueAsBytes(value));
        } catch (JsonProcessingException exception) {
            throw new IllegalStateException("Unable to serialize JWT", exception);
        }
    }

    private String sign(String signingInput) {
        return BASE64_URL_ENCODER.encodeToString(signBytes(signingInput));
    }

    private byte[] signBytes(String signingInput) {
        try {
            Mac mac = Mac.getInstance(HMAC_ALGORITHM);
            mac.init(new SecretKeySpec(jwtSecret().getBytes(StandardCharsets.UTF_8), HMAC_ALGORITHM));
            return mac.doFinal(signingInput.getBytes(StandardCharsets.UTF_8));
        } catch (Exception exception) {
            throw new IllegalStateException("Unable to sign JWT", exception);
        }
    }

    private String jwtSecret() {
        String secret = blogProperties.getSecurity().getJwtSecret();
        if (!StringUtils.hasText(secret)) {
            throw new IllegalStateException("blog.security.jwt-secret must not be blank");
        }
        return secret;
    }

    public record JwtToken(String value, Instant expiresAt) {
    }
}
