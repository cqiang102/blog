package com.caoqiang.blog.config;

import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.IpUtils;
import tools.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;

/**
 * 基于 Redis 滑动窗口的 API 限流过滤器。
 * <p>
 * 核心机制：利用 Redis Lua 脚本实现原子性 INCR + EXPIRE，
 * 按"HTTP 方法 + URL 路径 + 客户端 IP"的粒度进行限流。
 * <p>
 * 预设限流规则：
 * <ul>
 *     <li>登录接口 — 5 次/分钟</li>
 *     <li>注册接口 — 3 次/分钟</li>
 *     <li>文章浏览量统计 — 10 次/分钟</li>
 *     <li>AI 对话接口 — 10 次/分钟</li>
 *     <li>AI 流式对话接口 — 10 次/分钟</li>
 *     <li>其他接口 — 60 次/分钟（默认）</li>
 * </ul>
 * <p>
 * 响应头中包含 {@code X-RateLimit-Limit}、{@code X-RateLimit-Remaining}、{@code Retry-After}，
 * 方便客户端感知限流状态。超出限制时返回 HTTP 429。
 *
 * @author caoqiang
 */
public class RateLimitFilter extends OncePerRequestFilter {

    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;
    private final Map<String, RateLimitConfig> rules;

    /**
     * Lua 脚本：原子性 INCR + EXPIRE。
     * <p>
     * 如果 key 不存在，先设置过期时间再递增；
     * 如果 key 已存在，直接递增。
     * 保证 INCR 和 EXPIRE 的原子性，避免竞态条件。
     */
    private static final String INCR_EXPIRE_LUA = """
            local current = redis.call('INCR', KEYS[1])
            if current == 1 then
                redis.call('EXPIRE', KEYS[1], ARGV[1])
            end
            return current
            """;

    private final DefaultRedisScript<Long> incrExpireScript;

    public RateLimitFilter(StringRedisTemplate redisTemplate, ObjectMapper objectMapper) {
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
        this.rules = new ConcurrentHashMap<>();
        this.incrExpireScript = new DefaultRedisScript<>(INCR_EXPIRE_LUA, Long.class);
        initDefaultRules();
    }

    /**
     * 初始化默认限流规则。
     * <p>
     * key 格式为 "HTTP方法:路径模式"，路径中的 {@code *} 为通配符，匹配任意非斜杠字符。
     */
    private void initDefaultRules() {
        rules.put("POST:/api/v1/auth/login", new RateLimitConfig(5, 60));
        rules.put("POST:/api/v1/auth/register", new RateLimitConfig(3, 60));
        rules.put("POST:/api/v1/contents/*/views", new RateLimitConfig(10, 60));
        rules.put("POST:/api/v1/ai/chat", new RateLimitConfig(10, 60));
        rules.put("POST:/api/v1/ai/chat/stream", new RateLimitConfig(10, 60));
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

        String clientIp = IpUtils.getClientIp(request);
        String matchedPattern = matchPath(method, path);
        RateLimitConfig config = rules.getOrDefault(matchedPattern, rules.get("default"));

        String key = "rate:" + matchedPattern.replace("*", "_") + ":" + clientIp;

        // 使用 Lua 脚本原子性执行 INCR + EXPIRE，避免竞态条件
        Long count = redisTemplate.execute(incrExpireScript, java.util.Collections.singletonList(key), String.valueOf(config.windowSeconds()));

        if (count == null) {
            count = 1L;
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

    /**
     * 匹配请求路径对应的限流规则。
     * <p>
     * 优先精确匹配，其次尝试通配符匹配，均未命中则返回默认规则。
     *
     * @param method HTTP 方法
     * @param path   请求路径
     * @return 匹配到的规则 key
     */
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

    /**
     * 通配符路径匹配：将 {@code *} 转换为正则 {@code [^/]+} 进行匹配。
     */
    private boolean matchWildcard(String pattern, String path) {
        String regex = pattern.replace("*", "[^/]+");
        return path.matches(regex);
    }

    /**
     * 限流规则记录。
     *
     * @param maxRequests   窗口期内允许的最大请求数
     * @param windowSeconds 窗口时长（秒）
     */
    public record RateLimitConfig(int maxRequests, int windowSeconds) {
    }
}
