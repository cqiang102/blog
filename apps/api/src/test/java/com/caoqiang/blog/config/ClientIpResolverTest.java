package com.caoqiang.blog.config;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockHttpServletRequest;

class ClientIpResolverTest {

    @Test
    void ignoresForwardedHeadersFromAnUntrustedPeer() {
        ClientIpResolver resolver = resolver(List.of());
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("192.0.2.8");
        request.addHeader("X-Real-IP", "203.0.113.10");
        request.addHeader("X-Forwarded-For", "198.51.100.99");

        assertThat(resolver.resolve(request)).isEqualTo("192.0.2.8");
    }

    @Test
    void returnsTheFirstUntrustedAddressFromTheRightOfATrustedChain() {
        ClientIpResolver resolver = resolver(List.of("10.0.0.0/8", "192.168.0.0/16"));
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("10.0.0.2");
        request.addHeader("X-Forwarded-For", "198.51.100.99, 203.0.113.10, 192.168.1.5");

        assertThat(resolver.resolve(request)).isEqualTo("203.0.113.10");
    }

    @Test
    void rejectsMalformedForwardedAddresses() {
        ClientIpResolver resolver = resolver(List.of("10.0.0.0/8"));
        MockHttpServletRequest request = new MockHttpServletRequest();
        request.setRemoteAddr("10.0.0.2");
        request.addHeader("X-Forwarded-For", "not-an-ip");

        assertThat(resolver.resolve(request)).isEqualTo("10.0.0.2");
    }

    private ClientIpResolver resolver(List<String> trustedProxies) {
        BlogProperties properties = new BlogProperties();
        properties.getSecurity().setTrustedProxies(trustedProxies);
        return new ClientIpResolver(properties);
    }
}
