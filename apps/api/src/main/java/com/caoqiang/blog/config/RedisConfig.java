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
 *
 * @author caoqiang
 */
@Configuration
@EnableCaching
public class RedisConfig {

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
     *
     * @param connectionFactory Redis 连接工厂
     * @return RedisCacheManager 实例
     */
    @Bean
    public CacheManager cacheManager(RedisConnectionFactory connectionFactory) {
        // 默认缓存配置：5 分钟过期，Key 用 String 序列化，Value 用 JSON 序列化，禁止缓存 null
        RedisCacheConfiguration defaultConfig = RedisCacheConfiguration.defaultCacheConfig()
                .entryTtl(Duration.ofMinutes(5))
                .serializeKeysWith(
                        RedisSerializationContext.SerializationPair.fromSerializer(new StringRedisSerializer()))
                .serializeValuesWith(
                        RedisSerializationContext.SerializationPair.fromSerializer(new GenericJackson2JsonRedisSerializer()))
                .disableCachingNullValues();

        return RedisCacheManager.builder(connectionFactory)
                .cacheDefaults(defaultConfig)
                // 推荐内容：5 分钟缓存
                .withCacheConfiguration("recommendations",
                        RedisCacheConfiguration.defaultCacheConfig().entryTtl(Duration.ofMinutes(5)))
                // AI 每日配额：24 小时过期（与每日限额重置周期一致）
                .withCacheConfiguration("aiQuota",
                        RedisCacheConfiguration.defaultCacheConfig().entryTtl(Duration.ofHours(24)))
                // 知识库文档：30 分钟缓存
                .withCacheConfiguration("knowledgeDocs",
                        RedisCacheConfiguration.defaultCacheConfig().entryTtl(Duration.ofMinutes(30)))
                .build();
    }
}
