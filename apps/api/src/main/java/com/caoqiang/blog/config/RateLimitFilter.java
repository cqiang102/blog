package com.caoqiang.blog.config;

import com.caoqiang.blog.shared.response.ApiResponse;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.LongSupplier;
import java.util.regex.Pattern;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;
import tools.jackson.databind.ObjectMapper;

/**
 * 基于 Redis 固定窗口的 API 限流过滤器。
 * <p>
 * 核心机制：利用 Redis Lua 脚本实现原子性 INCR + EXPIRE，
 * 按"HTTP 方法 + URL 路径 + 客户端 IP"的粒度进行限流。
 * 使用 Lua 脚本而非分开执行 INCR+EXPIRE 是因为 Redis 单线程模型下，
 * 两条命令之间可能被其他客户端插入，导致 key 过期时间未设置。
 * <p>
 * 限流参数通过 {@link BlogProperties.RateLimit} 配置，可通过配置文件覆盖。
 * <p>
 * 响应头中包含 {@code X-RateLimit-Limit}、{@code X-RateLimit-Remaining}、{@code Retry-After}，
 * 方便客户端感知限流状态。超出限制时返回 HTTP 429。
 *
 * @author caoqiang
 */
public class RateLimitFilter extends OncePerRequestFilter {

    private static final Logger log = LoggerFactory.getLogger(RateLimitFilter.class);
    static final long REDIS_FAILURE_WARNING_INTERVAL_MILLIS = 60_000L;

    private final StringRedisTemplate redisTemplate;
    private final ObjectMapper objectMapper;
    private final ClientIpResolver clientIpResolver;
    private final Map<String, RateLimitRule> rules;
    private final Map<String, Pattern> compiledPatterns = new ConcurrentHashMap<>();
    private final LocalFixedWindowRateLimiter localRateLimiter = new LocalFixedWindowRateLimiter();
    private final LongSupplier currentTimeMillis;
    private final AtomicLong nextRedisFailureWarningAt = new AtomicLong();

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

    public RateLimitFilter(
            StringRedisTemplate redisTemplate,
            ObjectMapper objectMapper,
            BlogProperties blogProperties,
            ClientIpResolver clientIpResolver) {
        this(redisTemplate, objectMapper, blogProperties, clientIpResolver, System::currentTimeMillis);
    }

    RateLimitFilter(
            StringRedisTemplate redisTemplate,
            ObjectMapper objectMapper,
            BlogProperties blogProperties,
            ClientIpResolver clientIpResolver,
            LongSupplier currentTimeMillis) {
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
        this.clientIpResolver = clientIpResolver;
        this.currentTimeMillis = currentTimeMillis;
        this.rules = new ConcurrentHashMap<>();
        this.incrExpireScript = new DefaultRedisScript<>(INCR_EXPIRE_LUA, Long.class);
        initDefaultRules(blogProperties.getRateLimit());
    }

    /**
     * 初始化默认限流规则，参数从配置中读取。
     * <p>
     * key 格式为 "HTTP方法:路径模式"，路径中的 {@code *} 为通配符，匹配任意非斜杠字符。
     */
    private void initDefaultRules(BlogProperties.RateLimit config) {
        int window = config.getWindowSeconds();
        rules.put("POST:/api/v1/auth/login", new RateLimitRule(config.getLoginMaxRequests(), window));
        rules.put("POST:/api/v1/auth/register", new RateLimitRule(config.getRegisterMaxRequests(), window));
        rules.put("POST:/api/v1/auth/send-code", new RateLimitRule(config.getVerificationCodeMaxRequests(), window));
        rules.put("POST:/api/v1/contents/*/views", new RateLimitRule(config.getViewsMaxRequests(), window));
        rules.put("POST:/api/v1/ai/chat", new RateLimitRule(config.getAiChatMaxRequests(), window));
        rules.put("POST:/api/v1/ai/chat/stream", new RateLimitRule(config.getAiChatMaxRequests(), window));
        rules.put("default", new RateLimitRule(config.getDefaultMaxRequests(), window));
    }

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
            throws ServletException, IOException {
        String method = request.getMethod();
        String path = normalizePath(request.getRequestURI());

        if ("OPTIONS".equalsIgnoreCase(method) || path.startsWith("/actuator/")) {
            filterChain.doFilter(request, response);
            return;
        }

        String clientIp = clientIpResolver.resolve(request);
        String matchedPattern = matchPath(method, path);
        RateLimitRule config = rules.getOrDefault(matchedPattern, rules.get("default"));

        String bucket = "default".equals(matchedPattern) ? method + ":default" : matchedPattern;
        String key = "rate:" + bucket.replace("*", "_") + ":" + clientIp;

        Long count;
        try {
            count = redisTemplate.execute(
                    incrExpireScript, java.util.Collections.singletonList(key), String.valueOf(config.windowSeconds()));
        } catch (RuntimeException exception) {
            if (shouldLogRedisFailure()) {
                log.warn(
                        "Redis rate limiter unavailable; using the fixed-memory local fallback: {}",
                        exception.getClass().getSimpleName());
            } else {
                log.debug("Redis rate limiter remains unavailable", exception);
            }
            response.setHeader("X-RateLimit-Policy", "local-fallback");
            count = incrementLocalWindow(key, config.windowSeconds());
        }

        if (count == null) {
            response.setHeader("X-RateLimit-Policy", "local-fallback");
            count = incrementLocalWindow(key, config.windowSeconds());
        }

        response.setHeader("X-RateLimit-Limit", String.valueOf(config.maxRequests()));
        response.setHeader("X-RateLimit-Remaining", String.valueOf(Math.max(0, config.maxRequests() - count)));

        if (count > config.maxRequests()) {
            response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
            response.setCharacterEncoding(StandardCharsets.UTF_8.name());
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
     * 通配符路径匹配：使用预编译的正则表达式进行匹配。
     * <p>
     * 将 {@code *} 转换为正则 {@code [^/]+}，并缓存编译后的 Pattern 对象，
     * 避免每次请求都重新编译正则表达式。
     */
    private boolean matchWildcard(String pattern, String path) {
        Pattern compiled = compiledPatterns.computeIfAbsent(pattern, p -> Pattern.compile(p.replace("*", "[^/]+")));
        return compiled.matcher(path).matches();
    }

    /**
     * 规范化请求路径，防止通过分号（matrix params）、URL 编码或尾部斜杠绕过限流规则。
     */
    private static String normalizePath(String uri) {
        // 去除分号及其后的 matrix parameters（如 /login;x=1）
        int semicolon = uri.indexOf(';');
        String path = semicolon >= 0 ? uri.substring(0, semicolon) : uri;
        // URL 解码一次（防止 %6Cogin 绕过）
        try {
            path = java.net.URLDecoder.decode(path, StandardCharsets.UTF_8);
        } catch (IllegalArgumentException ignored) {
            // 非法编码保持原样
        }
        // 去除尾部斜杠（根路径除外）
        if (path.length() > 1 && path.endsWith("/")) {
            path = path.substring(0, path.length() - 1);
        }
        return path;
    }

    private long incrementLocalWindow(String key, int windowSeconds) {
        return localRateLimiter.increment(key, windowSeconds);
    }

    boolean shouldLogRedisFailure() {
        long now = currentTimeMillis.getAsLong();
        while (true) {
            long nextWarningAt = nextRedisFailureWarningAt.get();
            if (now < nextWarningAt) {
                return false;
            }
            long followingWarningAt = now + REDIS_FAILURE_WARNING_INTERVAL_MILLIS;
            if (nextRedisFailureWarningAt.compareAndSet(nextWarningAt, followingWarningAt)) {
                return true;
            }
        }
    }

    /**
     * 限流规则记录。
     *
     * @param maxRequests   窗口期内允许的最大请求数
     * @param windowSeconds 窗口时长（秒）
     */
    public record RateLimitRule(int maxRequests, int windowSeconds) {}
}
