package com.caoqiang.blog.config;

import org.springframework.boot.context.properties.ConfigurationProperties;

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

    public static class Ai {
        private int dailyQuestionLimit = 10;

        public int getDailyQuestionLimit() {
            return dailyQuestionLimit;
        }

        public void setDailyQuestionLimit(int dailyQuestionLimit) {
            this.dailyQuestionLimit = dailyQuestionLimit;
        }
    }

    public static class Admin {
        private final Bootstrap bootstrap = new Bootstrap();

        public Bootstrap getBootstrap() {
            return bootstrap;
        }

        public static class Bootstrap {
            private boolean enabled = false;
            private String email;
            private String password;
            private String nickname = "站长";

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

    public static class Security {
        private String jwtSecret;
        private int accessTokenMinutes = 30;
        private int refreshTokenDays = 30;

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

    public static class Storage {
        private String endpoint;
        private String accessKey;
        private String secretKey;
        private String bucket;
        private String publicBaseUrl = "http://localhost:8080";
        private long maxUploadBytes = 52_428_800;

        public String getEndpoint() {
            return endpoint;
        }

        public void setEndpoint(String endpoint) {
            this.endpoint = endpoint;
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

        public String getPublicBaseUrl() {
            return publicBaseUrl;
        }

        public void setPublicBaseUrl(String publicBaseUrl) {
            this.publicBaseUrl = publicBaseUrl;
        }

        public long getMaxUploadBytes() {
            return maxUploadBytes;
        }

        public void setMaxUploadBytes(long maxUploadBytes) {
            this.maxUploadBytes = maxUploadBytes;
        }
    }
}
