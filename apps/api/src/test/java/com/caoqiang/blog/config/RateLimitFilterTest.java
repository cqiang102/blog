package com.caoqiang.blog.config;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.concurrent.atomic.AtomicLong;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;
import tools.jackson.databind.ObjectMapper;

@ExtendWith(MockitoExtension.class)
class RateLimitFilterTest {

    @Mock
    private StringRedisTemplate redisTemplate;

    @Mock
    private FilterChain filterChain;

    private RateLimitFilter rateLimitFilter;
    private ObjectMapper objectMapper;

    @BeforeEach
    void setUp() {
        objectMapper = new ObjectMapper();
        BlogProperties blogProperties = new BlogProperties();
        rateLimitFilter =
                new RateLimitFilter(redisTemplate, objectMapper, blogProperties, new ClientIpResolver(blogProperties));
    }

    @Test
    void allowsRequestsWithinLimit() throws ServletException, IOException {
        when(redisTemplate.execute(
                        org.mockito.ArgumentMatchers.<DefaultRedisScript<Long>>any(), anyList(), anyString()))
                .thenReturn(1L);

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setMethod("GET");
        request.setRequestURI("/api/v1/contents");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        assertEquals("60", response.getHeader("X-RateLimit-Limit"));
        assertEquals("59", response.getHeader("X-RateLimit-Remaining"));
    }

    @Test
    void blocksRequestsOverLimit() throws ServletException, IOException {
        when(redisTemplate.execute(
                        org.mockito.ArgumentMatchers.<DefaultRedisScript<Long>>any(), anyList(), anyString()))
                .thenReturn(61L);

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setMethod("GET");
        request.setRequestURI("/api/v1/contents");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, never()).doFilter(request, response);
        assertEquals(429, response.getStatus());
        assertEquals(StandardCharsets.UTF_8.name(), response.getCharacterEncoding());
        assertTrue(response.getContentAsString().contains("请求过于频繁，请稍后再试"));
        assertNotNull(response.getHeader("Retry-After"));
    }

    @Test
    void skipsOptionsRequests() throws ServletException, IOException {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setMethod("OPTIONS");
        request.setRequestURI("/api/v1/contents");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        verifyNoInteractions(redisTemplate);
    }

    @Test
    void skipsActuatorEndpoints() throws ServletException, IOException {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setMethod("GET");
        request.setRequestURI("/actuator/health");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        verifyNoInteractions(redisTemplate);
    }

    @Test
    void usesStricterLimitForLoginEndpoint() throws ServletException, IOException {
        when(redisTemplate.execute(
                        org.mockito.ArgumentMatchers.<DefaultRedisScript<Long>>any(), anyList(), anyString()))
                .thenReturn(1L);

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setMethod("POST");
        request.setRequestURI("/api/v1/auth/login");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        assertEquals("5", response.getHeader("X-RateLimit-Limit"));
    }

    @Test
    void usesStricterLimitForRegisterEndpoint() throws ServletException, IOException {
        when(redisTemplate.execute(
                        org.mockito.ArgumentMatchers.<DefaultRedisScript<Long>>any(), anyList(), anyString()))
                .thenReturn(1L);

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setMethod("POST");
        request.setRequestURI("/api/v1/auth/register");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        assertEquals("3", response.getHeader("X-RateLimit-Limit"));
    }

    @Test
    void usesStricterLimitForVerificationCodeEndpoint() throws ServletException, IOException {
        when(redisTemplate.execute(
                        org.mockito.ArgumentMatchers.<DefaultRedisScript<Long>>any(), anyList(), anyString()))
                .thenReturn(1L);

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setMethod("POST");
        request.setRequestURI("/api/v1/auth/send-code");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        assertEquals("3", response.getHeader("X-RateLimit-Limit"));
    }

    @Test
    void usesLocalFallbackWhenRedisIsUnavailable() throws ServletException, IOException {
        when(redisTemplate.execute(
                        org.mockito.ArgumentMatchers.<DefaultRedisScript<Long>>any(), anyList(), anyString()))
                .thenThrow(new IllegalStateException("redis unavailable"));

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setMethod("GET");
        request.setRequestURI("/api/v1/contents");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        assertEquals("local-fallback", response.getHeader("X-RateLimit-Policy"));
    }

    @Test
    void rateLimitsRedisFailureWarnings() {
        AtomicLong now = new AtomicLong(1_000L);
        BlogProperties blogProperties = new BlogProperties();
        RateLimitFilter filter = new RateLimitFilter(
                redisTemplate, objectMapper, blogProperties, new ClientIpResolver(blogProperties), now::get);

        assertTrue(filter.shouldLogRedisFailure());
        assertFalse(filter.shouldLogRedisFailure());
        now.addAndGet(RateLimitFilter.REDIS_FAILURE_WARNING_INTERVAL_MILLIS);
        assertTrue(filter.shouldLogRedisFailure());
    }

    @Test
    void usesLocalFallbackWhenRedisReturnsNoCounter() throws ServletException, IOException {
        when(redisTemplate.execute(
                        org.mockito.ArgumentMatchers.<DefaultRedisScript<Long>>any(), anyList(), anyString()))
                .thenReturn(null);
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setMethod("GET");
        request.setRequestURI("/api/v1/contents");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        assertEquals("local-fallback", response.getHeader("X-RateLimit-Policy"));
        assertEquals("59", response.getHeader("X-RateLimit-Remaining"));
    }

    @Test
    void usesABoundedDefaultBucketInsteadOfRawRequestPaths() throws ServletException, IOException {
        java.util.List<java.util.List<String>> keys = new ArrayList<>();
        when(redisTemplate.execute(
                        org.mockito.ArgumentMatchers.<DefaultRedisScript<Long>>any(), anyList(), anyString()))
                .thenAnswer(invocation -> {
                    keys.add(new ArrayList<>(invocation.getArgument(1)));
                    return 1L;
                });

        MockHttpServletRequest contents = new MockHttpServletRequest();
        contents.setMethod("GET");
        contents.setRequestURI("/api/v1/contents");
        rateLimitFilter.doFilterInternal(contents, new MockHttpServletResponse(), filterChain);

        MockHttpServletRequest profile = new MockHttpServletRequest();
        profile.setMethod("GET");
        profile.setRequestURI("/api/v1/me");
        rateLimitFilter.doFilterInternal(profile, new MockHttpServletResponse(), filterChain);

        assertEquals(keys.get(0), keys.get(1));
        assertTrue(keys.getFirst().getFirst().contains("GET:default"));
    }
}
