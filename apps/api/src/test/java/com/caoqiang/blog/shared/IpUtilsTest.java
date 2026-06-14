package com.caoqiang.blog.shared;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.shared.util.IpUtils;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

class IpUtilsTest {

    @Test
    void prefersTheProxyNormalizedRealIpOverSpoofableForwardedEntries() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.addHeader("X-Real-IP", "203.0.113.10");
        request.addHeader("X-Forwarded-For", "198.51.100.99, 203.0.113.10");

        assertThat(IpUtils.getClientIp(request)).isEqualTo("203.0.113.10");
    }

    @Test
    void fallsBackToTheConnectionAddressWithoutProxyHeaders() {
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("192.0.2.8");

        assertThat(IpUtils.getClientIp(request)).isEqualTo("192.0.2.8");
    }
}
