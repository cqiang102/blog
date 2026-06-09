package com.caoqiang.blog.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

/**
 * 博客系统全局配置属性类。
 * <p>
 * 映射以 {@code blog.} 为前缀的配置项，采用嵌套结构组织为四大模块：
 * <ul>
 *     <li>{@link Ai} — AI 助手相关配置（每日提问限额等）</li>
 *     <li>{@link Admin} — 管理员初始化配置（首次启动引导创建管理员账户）</li>
 *     <li>{@link Security} — 安全认证配置（JWT 密钥、Token 有效期）</li>
 *     <li>{@link RateLimit} — API 限流配置（各端点请求频率限制）</li>
 * </ul>
 * <p>
 * 通过 {@code @ConfigurationPropertiesScan} 在应用启动时自动注册，无需显式 {@code @EnableConfigurationProperties}。
 *
 * @author caoqiang
 */
@ConfigurationProperties(prefix = "blog")
public class BlogProperties {

    private final Ai ai = new Ai();
    private final Admin admin = new Admin();
    private final Security security = new Security();
    private final RateLimit rateLimit = new RateLimit();
    private final Cache cache = new Cache();

    public Ai getAi() {
        return ai;
    }

    public Admin getAdmin() {
        return admin;
    }

    public Security getSecurity() {
        return security;
    }

    public RateLimit getRateLimit() {
        return rateLimit;
    }

    public Cache getCache() {
        return cache;
    }

    /**
     * AI 助手配置。
     */
    public static class Ai {
        /** 每用户每日 AI 提问次数上限，默认 10 次 */
        private int dailyQuestionLimit = 10;

        public int getDailyQuestionLimit() {
            return dailyQuestionLimit;
        }

        public void setDailyQuestionLimit(int dailyQuestionLimit) {
            this.dailyQuestionLimit = dailyQuestionLimit;
        }
    }

    /**
     * 管理员配置，包含首次启动时的引导创建逻辑。
     */
    public static class Admin {
        private final Bootstrap bootstrap = new Bootstrap();

        public Bootstrap getBootstrap() {
            return bootstrap;
        }

        /**
         * 管理员引导创建配置。
         * <p>
         * 当 {@code enabled=true} 时，应用首次启动会自动创建管理员账户。
         */
        public static class Bootstrap {
            private boolean enabled = false; // 是否启用管理员引导创建
            private String email;            // 管理员邮箱
            private String password;         // 管理员密码（明文，启动后会被 BCrypt 加密存储）
            private String nickname = "站长"; // 管理员昵称，默认"站长"

            public boolean isEnabled() {
                return enabled;
            }

            public void setEnabled(boolean enabled) {
                this.enabled = enabled;
            }

            public String getEmail() {
                return email;
            }

            public void setEmail(String email) {
                this.email = email;
            }

            public String getPassword() {
                return password;
            }

            public void setPassword(String password) {
                this.password = password;
            }

            public String getNickname() {
                return nickname;
            }

            public void setNickname(String nickname) {
                this.nickname = nickname;
            }
        }
    }

    /**
     * 安全认证配置，控制 JWT 签发和 Token 有效期。
     */
    public static class Security {
        private String jwtSecret;                    // JWT 签名密钥（HMAC），必须配置为高强度随机字符串
        private int accessTokenMinutes = 30;         // 访问令牌有效期，默认 30 分钟
        private int refreshTokenDays = 30;           // 刷新令牌有效期，默认 30 天

        public String getJwtSecret() {
            return jwtSecret;
        }

        public void setJwtSecret(String jwtSecret) {
            this.jwtSecret = jwtSecret;
        }

        public int getAccessTokenMinutes() {
            return accessTokenMinutes;
        }

        public void setAccessTokenMinutes(int accessTokenMinutes) {
            this.accessTokenMinutes = accessTokenMinutes;
        }

        public int getRefreshTokenDays() {
            return refreshTokenDays;
        }

        public void setRefreshTokenDays(int refreshTokenDays) {
            this.refreshTokenDays = refreshTokenDays;
        }
    }

    /**
     * API 限流配置。
     * <p>
     * 各端点的限流参数可通过 {@code blog.rate-limit.*} 配置项覆盖，
     * 避免在代码中硬编码限流数值。
     */
    public static class RateLimit {
        /** 登录接口每分钟最大请求数 */
        private int loginMaxRequests = 5;
        /** 注册接口每分钟最大请求数 */
        private int registerMaxRequests = 3;
        /** 文章浏览量统计接口每分钟最大请求数 */
        private int viewsMaxRequests = 10;
        /** AI 对话接口每分钟最大请求数 */
        private int aiChatMaxRequests = 10;
        /** 其他接口每分钟最大请求数 */
        private int defaultMaxRequests = 60;
        /** 限流窗口时长（秒） */
        private int windowSeconds = 60;

        public int getLoginMaxRequests() { return loginMaxRequests; }
        public void setLoginMaxRequests(int loginMaxRequests) { this.loginMaxRequests = loginMaxRequests; }
        public int getRegisterMaxRequests() { return registerMaxRequests; }
        public void setRegisterMaxRequests(int registerMaxRequests) { this.registerMaxRequests = registerMaxRequests; }
        public int getViewsMaxRequests() { return viewsMaxRequests; }
        public void setViewsMaxRequests(int viewsMaxRequests) { this.viewsMaxRequests = viewsMaxRequests; }
        public int getAiChatMaxRequests() { return aiChatMaxRequests; }
        public void setAiChatMaxRequests(int aiChatMaxRequests) { this.aiChatMaxRequests = aiChatMaxRequests; }
        public int getDefaultMaxRequests() { return defaultMaxRequests; }
        public void setDefaultMaxRequests(int defaultMaxRequests) { this.defaultMaxRequests = defaultMaxRequests; }
        public int getWindowSeconds() { return windowSeconds; }
        public void setWindowSeconds(int windowSeconds) { this.windowSeconds = windowSeconds; }
    }

    /**
     * 缓存配置。
     * <p>
     * 各缓存名称的 TTL 可通过 {@code blog.cache.*} 配置项覆盖，
     * 避免在代码中硬编码缓存过期时间。
     */
    public static class Cache {
        /** 默认缓存 TTL（分钟） */
        private int defaultTtlMinutes = 5;
        /** 推荐内容缓存 TTL（分钟） */
        private int recommendationsTtlMinutes = 5;
        /** AI 配额缓存 TTL（小时） */
        private int aiQuotaTtlHours = 24;
        /** 知识库文档缓存 TTL（分钟） */
        private int knowledgeDocsTtlMinutes = 30;

        public int getDefaultTtlMinutes() { return defaultTtlMinutes; }
        public void setDefaultTtlMinutes(int defaultTtlMinutes) { this.defaultTtlMinutes = defaultTtlMinutes; }
        public int getRecommendationsTtlMinutes() { return recommendationsTtlMinutes; }
        public void setRecommendationsTtlMinutes(int recommendationsTtlMinutes) { this.recommendationsTtlMinutes = recommendationsTtlMinutes; }
        public int getAiQuotaTtlHours() { return aiQuotaTtlHours; }
        public void setAiQuotaTtlHours(int aiQuotaTtlHours) { this.aiQuotaTtlHours = aiQuotaTtlHours; }
        public int getKnowledgeDocsTtlMinutes() { return knowledgeDocsTtlMinutes; }
        public void setKnowledgeDocsTtlMinutes(int knowledgeDocsTtlMinutes) { this.knowledgeDocsTtlMinutes = knowledgeDocsTtlMinutes; }
    }
}
