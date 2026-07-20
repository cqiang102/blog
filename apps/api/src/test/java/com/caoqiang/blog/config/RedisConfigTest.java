package com.caoqiang.blog.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import com.caoqiang.blog.content.application.dto.ContentSummaryResponse;
import com.caoqiang.blog.content.application.dto.RecommendationResponse;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import java.nio.charset.StandardCharsets;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class RedisConfigTest {

    @Test
    void cacheValueSerializerKeepsRecommendationResponseType() {
        var serializer = RedisConfig.cacheValueSerializer();
        var summary = new ContentSummaryResponse(
                UUID.randomUUID(),
                "Test Article",
                "test-article",
                ContentType.ARTICLE,
                ContentStatus.PUBLISHED,
                "Summary",
                null,
                false,
                7,
                Instant.parse("2026-06-24T00:00:00Z"),
                List.of("Java", "Flutter"));
        var response = new RecommendationResponse(List.of(summary), List.of(summary), List.of(summary));

        byte[] serialized = serializer.serialize(response);
        assertNotNull(serialized);
        String json = new String(serialized, StandardCharsets.UTF_8);
        assertTrue(json.contains("\"@class\""));
        assertTrue(json.contains(RecommendationResponse.class.getName()));

        Object deserialized = serializer.deserialize(serialized);

        var cachedResponse = assertInstanceOf(RecommendationResponse.class, deserialized);
        assertEquals("Test Article", cachedResponse.latest().getFirst().title());
        assertEquals(ContentType.ARTICLE, cachedResponse.latest().getFirst().type());
    }

    @Test
    void cacheKeysUseVersionedPrefix() {
        assertEquals("blog-cache:v2:", RedisConfig.CACHE_KEY_PREFIX);
    }
}
