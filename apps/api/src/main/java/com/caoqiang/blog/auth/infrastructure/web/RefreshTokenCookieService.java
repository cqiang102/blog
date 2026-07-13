package com.caoqiang.blog.auth.infrastructure.web;

import com.caoqiang.blog.config.BlogProperties;
import jakarta.servlet.http.HttpServletResponse;
import java.time.Duration;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.stereotype.Component;

/** Keeps refresh tokens outside JavaScript-readable storage. */
@Component
public class RefreshTokenCookieService {

    public static final String COOKIE_NAME = "blog_refresh_token";
    private static final String COOKIE_PATH = "/api/v1/auth";

    private final BlogProperties blogProperties;

    public RefreshTokenCookieService(BlogProperties blogProperties) {
        this.blogProperties = blogProperties;
    }

    public void write(HttpServletResponse response, String refreshToken) {
        ResponseCookie cookie = baseCookie(refreshToken)
                .maxAge(Duration.ofDays(blogProperties.getSecurity().getRefreshTokenDays()))
                .build();
        response.addHeader(HttpHeaders.SET_COOKIE, cookie.toString());
    }

    public void clear(HttpServletResponse response) {
        ResponseCookie cookie = baseCookie("")
                .maxAge(Duration.ZERO)
                .build();
        response.addHeader(HttpHeaders.SET_COOKIE, cookie.toString());
    }

    private ResponseCookie.ResponseCookieBuilder baseCookie(String value) {
        return ResponseCookie.from(COOKIE_NAME, value)
                .httpOnly(true)
                .secure(blogProperties.getSecurity().isRefreshCookieSecure())
                .sameSite("Lax")
                .path(COOKIE_PATH);
    }
}
