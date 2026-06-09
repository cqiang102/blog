package com.caoqiang.blog.config;

import java.time.Duration;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.data.redis.cache.RedisCacheConfiguration;
import org.springframework.data.redis.cache.RedisCacheManager;
import org.springframework.data.redis.connection.RedisConnectionFactory;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.serializer.GenericJackson2JsonRedisSerializer;
import org.springframework.data.redis.serializer.RedisSerializationContext;
import org.springframework.data.redis.serializer.StringRedisSerializer;

/**
 * Redis 缓存配置类。
 * <p>
 * 通过 {@code @EnableCaching} 启用 Spring Cache 抽象，并基于 Redis 实现缓存管理器。
 * 为不同业务场景配置了差异化的 TTL 策略：
 * <ul>
 *     <li>{@code recommendations} — 推荐内容缓存，5 分钟过期</li>
 *     <li>{@code aiQuota} — AI 配额计数缓存，24 小时过期（每日限额重置）</li>
 *     <li>{@code knowledgeDocs} — 知识库文档缓存，30 分钟过期</li>
 * </ul>
 * <p>
 * 序列化策略：Key 使用 {@link StringRedisSerializer}，Value 使用 {@link GenericJackson2JsonRedisSerializer}，
 * 并禁用 null 值缓存以避免缓存穿透。
 * <p>
 * TTL 配置可通过 {@code blog.cache.*} 外部化配置覆盖。
 *
 * @author caoqiang
 */
@Configuration
@EnableCaching
public class RedisConfig {

    private final BlogProperties blogProperties;

    public RedisConfig(BlogProperties blogProperties) {
        this.blogProperties = blogProperties;
    }

    /**
     * 创建 StringRedisTemplate，用于 Redis 的字符串操作（如限流计数器）。
     *
     * @param connectionFactory Redis 连接工厂
     * @return StringRedisTemplate 实例
     */
    @Bean
    public StringRedisTemplate stringRedisTemplate(RedisConnectionFactory connectionFactory) {
        return new StringRedisTemplate(connectionFactory);
    }

    /**
     * 创建基于 Redis 的缓存管理器。
     * <p>
     * 默认 TTL 为 5 分钟，各缓存名称可单独覆盖 TTL 配置。
     * TTL 值从 {@link BlogProperties.Cache} 中读取，支持外部化配置。
     *
     * @param connectionFactory Redis 连接工厂
     * @return RedisCacheManager 实例
     */
    @Bean
    public CacheManager cacheManager(RedisConnectionFactory connectionFactory) {
        BlogProperties.Cache cacheConfig = blogProperties.getCache();

        // 默认缓存配置：Key 用 String 序列化，Value 用 JSON 序列化，禁止缓存 null
        RedisCacheConfiguration defaultConfig = RedisCacheConfiguration.defaultCacheConfig()
                .entryTtl(Duration.ofMinutes(cacheConfig.getDefaultTtlMinutes()))
                .serializeKeysWith(
                        RedisSerializationContext.SerializationPair.fromSerializer(new StringRedisSerializer()))
                .serializeValuesWith(
                        RedisSerializationContext.SerializationPair.fromSerializer(new GenericJackson2JsonRedisSerializer()))
                .disableCachingNullValues();

        return RedisCacheManager.builder(connectionFactory)
                .cacheDefaults(defaultConfig)
                // 推荐内容缓存
                .withCacheConfiguration(CacheNames.RECOMMENDATIONS,
                        RedisCacheConfiguration.defaultCacheConfig()
                                .entryTtl(Duration.ofMinutes(cacheConfig.getRecommendationsTtlMinutes())))
                // AI 每日配额缓存
                .withCacheConfiguration(CacheNames.AI_QUOTA,
                        RedisCacheConfiguration.defaultCacheConfig()
                                .entryTtl(Duration.ofHours(cacheConfig.getAiQuotaTtlHours())))
                // 知识库文档缓存
                .withCacheConfiguration(CacheNames.KNOWLEDGE_DOCS,
                        RedisCacheConfiguration.defaultCacheConfig()
                                .entryTtl(Duration.ofMinutes(cacheConfig.getKnowledgeDocsTtlMinutes())))
                .build();
    }
}
