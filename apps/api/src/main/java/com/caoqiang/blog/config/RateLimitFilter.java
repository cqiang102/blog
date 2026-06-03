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

/**
 * 基于 Redis 滑动窗口的 API 限流过滤器。
 * <p>
 * 核心机制：利用 Redis 的 {@code INCR} + {@code EXPIRE} 命令实现固定窗口计数器，
 * 按"HTTP 方法 + URL 路径 + 客户端 IP"的粒度进行限流。
 * <p>
 * 预设限流规则：
 * <ul>
 *     <li>登录接口 — 5 次/分钟</li>
 *     <li>注册接口 — 3 次/分钟</li>
 *     <li>文章浏览量统计 — 10 次/分钟</li>
 *     <li>AI 对话接口 — 10 次/分钟</li>
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
    private final Map<String, RateLimitConfig> rules; // 限流规则表：key 为 "METHOD:path" 模式

    public RateLimitFilter(StringRedisTemplate redisTemplate, ObjectMapper objectMapper) {
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
        this.rules = new ConcurrentHashMap<>();
        initDefaultRules();
    }

    /**
     * 初始化默认限流规则。
     * <p>
     * key 格式为 "HTTP方法:路径模式"，路径中的 {@code *} 为通配符，匹配任意非斜杠字符。
     */
    private void initDefaultRules() {
        rules.put("POST:/api/v1/auth/login", new RateLimitConfig(5, 60));       // 登录：5次/分钟
        rules.put("POST:/api/v1/auth/register", new RateLimitConfig(3, 60));    // 注册：3次/分钟
        rules.put("POST:/api/v1/contents/*/views", new RateLimitConfig(10, 60)); // 浏览量：10次/分钟
        rules.put("POST:/api/v1/ai/chat", new RateLimitConfig(10, 60));         // AI对话：10次/分钟
        rules.put("default", new RateLimitConfig(60, 60));                       // 默认：60次/分钟
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        String method = request.getMethod();
        String path = request.getRequestURI();

        // OPTIONS 预检请求和健康检查接口不限流
        if ("OPTIONS".equalsIgnoreCase(method) || path.startsWith("/actuator/")) {
            filterChain.doFilter(request, response);
            return;
        }

        String clientIp = getClientIp(request);
        String matchedPattern = matchPath(method, path);
        RateLimitConfig config = rules.getOrDefault(matchedPattern, rules.get("default"));

        // Redis 计数器 key：rate:{路径模式}:{客户端IP}
        String key = "rate:" + matchedPattern.replace("*", "_") + ":" + clientIp;
        // 原子递增计数器
        long count = redisTemplate.opsForValue().increment(key);

        // 首次请求时设置过期时间（固定窗口起点）
        if (count == 1) {
            redisTemplate.expire(key, config.windowSeconds(), TimeUnit.SECONDS);
        }

        // 设置限流响应头
        response.setHeader("X-RateLimit-Limit", String.valueOf(config.maxRequests()));
        response.setHeader("X-RateLimit-Remaining", String.valueOf(Math.max(0, config.maxRequests() - count)));

        // 超出限制：返回 429 Too Many Requests
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
        // 精确匹配
        String key = method + ":" + path;
        if (rules.containsKey(key)) {
            return key;
        }

        // 通配符匹配
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
     * 获取客户端真实 IP 地址。
     * <p>
     * 优先从 {@code X-Forwarded-For} 头部取第一个 IP（经过多级代理时），
     * 其次取 {@code X-Real-IP}，最后回退到 {@code getRemoteAddr()}。
     *
     * @param request HTTP 请求
     * @return 客户端 IP 地址
     */
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

    /**
     * 限流规则记录。
     *
     * @param maxRequests  窗口期内允许的最大请求数
     * @param windowSeconds 窗口时长（秒）
     */
    public record RateLimitConfig(int maxRequests, int windowSeconds) {
    }
}
