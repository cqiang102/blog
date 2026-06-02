package com.caoqiang.blog.config;

import com.caoqiang.blog.common.ApiResponse;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.TimeUnit;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

public class RateLimitFilter extends OncePerRequestFilter {

    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;
    private final Map<String, RateLimitConfig> rules;

    public RateLimitFilter(StringRedisTemplate redisTemplate, ObjectMapper objectMapper) {
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
        this.rules = new ConcurrentHashMap<>();
        initDefaultRules();
    }

    private void initDefaultRules() {
        rules.put("POST:/api/v1/auth/login", new RateLimitConfig(5, 60));
        rules.put("POST:/api/v1/auth/register", new RateLimitConfig(3, 60));
        rules.put("POST:/api/v1/contents/*/views", new RateLimitConfig(10, 60));
        rules.put("POST:/api/v1/ai/chat", new RateLimitConfig(10, 60));
        rules.put("default", new RateLimitConfig(60, 60));
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String method = request.getMethod();
        String path = request.getRequestURI();

        if ("OPTIONS".equalsIgnoreCase(method) || path.startsWith("/actuator/")) {
            filterChain.doFilter(request, response);
            return;
        }

        String clientIp = getClientIp(request);
        String matchedPattern = matchPath(method, path);
        RateLimitConfig config = rules.getOrDefault(matchedPattern, rules.get("default"));

        String key = "rate:" + matchedPattern.replace("*", "_") + ":" + clientIp;
        long count = redisTemplate.opsForValue().increment(key);

        if (count == 1) {
            redisTemplate.expire(key, config.windowSeconds(), TimeUnit.SECONDS);
        }

        response.setHeader("X-RateLimit-Limit", String.valueOf(config.maxRequests()));
        response.setHeader("X-RateLimit-Remaining", String.valueOf(Math.max(0, config.maxRequests() - count)));

        if (count > config.maxRequests()) {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setContentType(MediaType.APPLICATION_JSON_VALUE);
            response.setHeader("Retry-After", String.valueOf(config.windowSeconds()));

            ApiResponse<?> body = ApiResponse.fail("请求过于频繁，请稍后再试");
            response.getWriter().write(objectMapper.writeValueAsString(body));
            return;
        }

        filterChain.doFilter(request, response);
    }

    private String matchPath(String method, String path) {
        String key = method + ":" + path;
        if (rules.containsKey(key)) {
            return key;
        }

        for (String pattern : rules.keySet()) {
            if (pattern.equals("default")) continue;
            String[] parts = pattern.split(":");
            if (parts.length != 2) continue;
            if (!parts[0].equals(method)) continue;

            String patternPath = parts[1];
            if (matchWildcard(patternPath, path)) {
                return pattern;
            }
        }

        return "default";
    }

    private boolean matchWildcard(String pattern, String path) {
        String regex = pattern.replace("*", "[^/]+");
        return path.matches(regex);
    }

    private String getClientIp(HttpServletRequest request) {
        String xff = request.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isEmpty()) {
            return xff.split(",")[0].trim();
        }
        String realIp = request.getHeader("X-Real-IP");
        if (realIp != null && !realIp.isEmpty()) {
            return realIp;
        }
        return request.getRemoteAddr();
    }

    public record RateLimitConfig(int maxRequests, int windowSeconds) {
    }
}
