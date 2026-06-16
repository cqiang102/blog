package com.caoqiang.blog.config;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import tools.jackson.databind.ObjectMapper;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.StringRedisTemplate;
import org.springframework.data.redis.core.script.DefaultRedisScript;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

import java.io.IOException;
import java.util.ArrayList;

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
        rateLimitFilter = new RateLimitFilter(redisTemplate, objectMapper, blogProperties);
    }

    @Test
    void allowsRequestsWithinLimit() throws ServletException, IOException {
        when(redisTemplate.execute(
                org.mockito.ArgumentMatchers.<DefaultRedisScript<Long>>any(),
                anyList(),
                anyString()
        )).thenReturn(1L);

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
                org.mockito.ArgumentMatchers.<DefaultRedisScript<Long>>any(),
                anyList(),
                anyString()
        )).thenReturn(61L);

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setMethod("GET");
        request.setRequestURI("/api/v1/contents");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain, never()).doFilter(request, response);
        assertEquals(429, response.getStatus());
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
                org.mockito.ArgumentMatchers.<DefaultRedisScript<Long>>any(),
                anyList(),
                anyString()
        )).thenReturn(1L);

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
                org.mockito.ArgumentMatchers.<DefaultRedisScript<Long>>any(),
                anyList(),
                anyString()
        )).thenReturn(1L);

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setMethod("POST");
        request.setRequestURI("/api/v1/auth/register");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        assertEquals("3", response.getHeader("X-RateLimit-Limit"));
    }

    @Test
    void allowsRequestWhenRedisIsUnavailable() throws ServletException, IOException {
        when(redisTemplate.execute(
                org.mockito.ArgumentMatchers.<DefaultRedisScript<Long>>any(),
                anyList(),
                anyString()
        ))
                .thenThrow(new IllegalStateException("redis unavailable"));

        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setMethod("GET");
        request.setRequestURI("/api/v1/contents");
        MockHttpServletResponse response = new MockHttpServletResponse();

        rateLimitFilter.doFilterInternal(request, response, filterChain);

        verify(filterChain).doFilter(request, response);
        assertEquals("unavailable", response.getHeader("X-RateLimit-Policy"));
    }

    @Test
    void keepsDefaultRateLimitsSeparatePerMethodAndPath() throws ServletException, IOException {
        java.util.List<java.util.List<String>> keys = new ArrayList<>();
        when(redisTemplate.execute(
                org.mockito.ArgumentMatchers.<DefaultRedisScript<Long>>any(),
                anyList(),
                anyString()
        )).thenAnswer(invocation -> {
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

        assertNotEquals(keys.get(0), keys.get(1));
        assertTrue(keys.get(0).getFirst().contains("GET:/api/v1/contents"));
        assertTrue(keys.get(1).getFirst().contains("GET:/api/v1/me"));
    }
}
