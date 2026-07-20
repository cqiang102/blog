package com.caoqiang.blog.auth.infrastructure.web;

import com.caoqiang.blog.config.BlogProperties;
import jakarta.servlet.http.Cookie;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.Base64;
import java.util.regex.Pattern;
import org.springframework.http.HttpHeaders;
import org.springframework.http.ResponseCookie;
import org.springframework.stereotype.Component;

/** Maintains the HttpOnly browser identifier used to bind an OAuth state to its initiator. */
@Component
public class OAuthStateCookieService {

    public static final String COOKIE_NAME = "blog_oauth_browser";
    private static final String COOKIE_PATH = "/api/v1/auth";
    private static final Duration COOKIE_TTL = Duration.ofMinutes(10);
    private static final Pattern BROWSER_ID = Pattern.compile("[A-Za-z0-9_-]{43}");

    private final BlogProperties blogProperties;
    private final SecureRandom secureRandom = new SecureRandom();

    public OAuthStateCookieService(BlogProperties blogProperties) {
        this.blogProperties = blogProperties;
    }

    public String resolveOrCreate(HttpServletRequest request, HttpServletResponse response) {
        String browserId = read(request);
        if (browserId == null) {
            byte[] bytes = new byte[32];
            secureRandom.nextBytes(bytes);
            browserId = Base64.getUrlEncoder().withoutPadding().encodeToString(bytes);
        }
        write(response, browserId);
        return browserId;
    }

    public String read(HttpServletRequest request) {
        Cookie[] cookies = request.getCookies();
        if (cookies == null) {
            return null;
        }
        for (Cookie cookie : cookies) {
            if (COOKIE_NAME.equals(cookie.getName())
                    && BROWSER_ID.matcher(cookie.getValue()).matches()) {
                return cookie.getValue();
            }
        }
        return null;
    }

    private void write(HttpServletResponse response, String browserId) {
        ResponseCookie cookie = ResponseCookie.from(COOKIE_NAME, browserId)
                .httpOnly(true)
                .secure(blogProperties.getSecurity().isRefreshCookieSecure())
                .sameSite("Lax")
                .path(COOKIE_PATH)
                .maxAge(COOKIE_TTL)
                .build();
        response.addHeader(HttpHeaders.SET_COOKIE, cookie.toString());
    }
}
