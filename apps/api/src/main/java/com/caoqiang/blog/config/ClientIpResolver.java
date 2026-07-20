package com.caoqiang.blog.config;

import jakarta.servlet.http.HttpServletRequest;
import java.util.ArrayList;
import java.util.List;
import org.springframework.security.web.util.matcher.IpAddressMatcher;
import org.springframework.stereotype.Component;

/** Resolves a client address without trusting headers from direct clients. */
@Component
public final class ClientIpResolver {

    private static final String UNKNOWN_ADDRESS = "unknown";

    private final List<IpAddressMatcher> trustedProxies;

    public ClientIpResolver(BlogProperties blogProperties) {
        this.trustedProxies = blogProperties.getSecurity().getTrustedProxies().stream()
                .filter(value -> value != null && !value.isBlank())
                .map(String::trim)
                .map(IpAddressMatcher::new)
                .toList();
    }

    public String resolve(HttpServletRequest request) {
        String remoteAddress = validAddress(request.getRemoteAddr());
        if (UNKNOWN_ADDRESS.equals(remoteAddress) || !isTrustedProxy(remoteAddress)) {
            return remoteAddress;
        }

        List<String> forwardedChain = forwardedChain(request.getHeader("X-Forwarded-For"));
        for (int index = forwardedChain.size() - 1; index >= 0; index--) {
            String candidate = forwardedChain.get(index);
            if (!isTrustedProxy(candidate)) {
                return candidate;
            }
        }

        String realIp = validAddress(request.getHeader("X-Real-IP"));
        return UNKNOWN_ADDRESS.equals(realIp) ? remoteAddress : realIp;
    }

    private List<String> forwardedChain(String header) {
        if (header == null || header.isBlank()) {
            return List.of();
        }
        List<String> addresses = new ArrayList<>();
        for (String value : header.split(",")) {
            String address = validAddress(value);
            if (!UNKNOWN_ADDRESS.equals(address)) {
                addresses.add(address);
            }
        }
        return addresses;
    }

    private boolean isTrustedProxy(String address) {
        return trustedProxies.stream().anyMatch(matcher -> matcher.matches(address));
    }

    private String validAddress(String value) {
        if (value == null || value.isBlank()) {
            return UNKNOWN_ADDRESS;
        }
        String candidate = value.trim();
        try {
            return new IpAddressMatcher(candidate).matches(candidate) ? candidate : UNKNOWN_ADDRESS;
        } catch (IllegalArgumentException exception) {
            return UNKNOWN_ADDRESS;
        }
    }
}
