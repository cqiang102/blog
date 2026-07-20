package com.caoqiang.blog.auth;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.auth.infrastructure.web.OAuthStateCookieService;
import com.caoqiang.blog.config.BlogProperties;
import jakarta.servlet.http.Cookie;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;
import org.springframework.mock.web.MockHttpServletResponse;

class OAuthStateCookieServiceTest {

    @Test
    void createsHttpOnlyBrowserCookieAndReusesItAcrossConcurrentFlows() {
        BlogProperties properties = new BlogProperties();
        properties.getSecurity().setRefreshCookieSecure(true);
        OAuthStateCookieService service = new OAuthStateCookieService(properties);
        MockHttpServletResponse firstResponse = new MockHttpServletResponse();

        String browserId = service.resolveOrCreate(new MockHttpServletRequest(), firstResponse);

        assertThat(browserId).matches("[A-Za-z0-9_-]{43}");
        assertThat(firstResponse.getHeader("Set-Cookie"))
                .contains(OAuthStateCookieService.COOKIE_NAME + "=" + browserId)
                .contains("Path=/api/v1/auth")
                .contains("Secure")
                .contains("HttpOnly")
                .contains("SameSite=Lax");

        MockHttpServletRequest secondRequest = new MockHttpServletRequest();
        secondRequest.setCookies(new Cookie(OAuthStateCookieService.COOKIE_NAME, browserId));
        String reused = service.resolveOrCreate(secondRequest, new MockHttpServletResponse());

        assertThat(reused).isEqualTo(browserId);
    }

    @Test
    void ignoresMalformedBrowserCookie() {
        OAuthStateCookieService service = new OAuthStateCookieService(new BlogProperties());
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setCookies(new Cookie(OAuthStateCookieService.COOKIE_NAME, "attacker-controlled"));

        String regenerated = service.resolveOrCreate(request, new MockHttpServletResponse());

        assertThat(regenerated).matches("[A-Za-z0-9_-]{43}").isNotEqualTo("attacker-controlled");
    }
}
