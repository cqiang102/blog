package com.caoqiang.blog.config;

import static org.assertj.core.api.Assertions.assertThat;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;
import org.springframework.context.annotation.Configuration;

class BlogPropertiesValidationTest {

    private static final String VALID_JWT_SECRET =
            "blog.security.jwt-secret=test-only-jwt-secret-with-at-least-32-characters";

    private final ApplicationContextRunner contextRunner = new ApplicationContextRunner()
            .withUserConfiguration(TestConfiguration.class)
            .withPropertyValues(VALID_JWT_SECRET);

    @Test
    void acceptsPositiveDefaults() {
        contextRunner.run(context -> {
            assertThat(context).hasNotFailed();
            assertThat(context).hasSingleBean(BlogProperties.class);
        });
    }

    @ParameterizedTest
    @ValueSource(
            strings = {
                "blog.ai.daily-question-limit=0",
                "blog.rate-limit.login-max-requests=0",
                "blog.rate-limit.register-max-requests=0",
                "blog.rate-limit.verification-code-max-requests=0",
                "blog.rate-limit.views-max-requests=0",
                "blog.rate-limit.ai-chat-max-requests=0",
                "blog.rate-limit.default-max-requests=0",
                "blog.rate-limit.window-seconds=0",
                "blog.cache.default-ttl-minutes=0",
                "blog.cache.recommendations-ttl-minutes=0",
                "blog.cache.ai-quota-ttl-hours=0",
                "blog.cache.knowledge-docs-ttl-minutes=0"
            })
    void rejectsNonPositiveOperationalLimits(String invalidProperty) {
        contextRunner
                .withPropertyValues(invalidProperty)
                .run(context -> assertThat(context).hasFailed());
    }

    @Configuration(proxyBeanMethods = false)
    @EnableConfigurationProperties(BlogProperties.class)
    static class TestConfiguration {}
}
