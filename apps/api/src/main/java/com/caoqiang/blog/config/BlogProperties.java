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
 *     <li>{@link Storage} — 对象存储配置（MinIO 连接信息、上传限制）</li>
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
    private final Storage storage = new Storage();

    public Ai getAi() {
        return ai;
    }

    public Admin getAdmin() {
        return admin;
    }

    public Security getSecurity() {
        return security;
    }

    public Storage getStorage() {
        return storage;
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
     * 对象存储（MinIO）配置。
     */
    public static class Storage {
        private String endpoint;                                  // MinIO 内部服务端点 URL（API 服务器访问用）
        private String publicEndpoint;                            // MinIO 公开端点 URL（浏览器访问用，用于预签名 URL）
        private String accessKey;                                 // 访问密钥 ID
        private String secretKey;                                 // 访问密钥 Secret
        private String bucket;                                    // 存储桶名称
        private long maxUploadBytes = 52_428_800;                 // 单文件上传大小上限，默认 50MB

        public String getEndpoint() {
            return endpoint;
        }

        public void setEndpoint(String endpoint) {
            this.endpoint = endpoint;
        }

        public String getPublicEndpoint() {
            return publicEndpoint;
        }

        public void setPublicEndpoint(String publicEndpoint) {
            this.publicEndpoint = publicEndpoint;
        }

        public String getAccessKey() {
            return accessKey;
        }

        public void setAccessKey(String accessKey) {
            this.accessKey = accessKey;
        }

        public String getSecretKey() {
            return secretKey;
        }

        public void setSecretKey(String secretKey) {
            this.secretKey = secretKey;
        }

        public String getBucket() {
            return bucket;
        }

        public void setBucket(String bucket) {
            this.bucket = bucket;
        }

        public long getMaxUploadBytes() {
            return maxUploadBytes;
        }

        public void setMaxUploadBytes(long maxUploadBytes) {
            this.maxUploadBytes = maxUploadBytes;
        }
    }
}
