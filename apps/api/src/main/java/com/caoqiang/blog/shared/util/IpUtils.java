package com.caoqiang.blog.shared.util;

import jakarta.servlet.http.HttpServletRequest;

/**
 * IP 地址工具类。
 * <p>
 * 提供获取客户端真实 IP 地址的统一方法，支持多级代理场景。
 *
 * @author caoqiang
 */
public final class IpUtils {

    private IpUtils() {
    }

    /**
     * 获取客户端真实 IP 地址。
     * <p>
     * 优先使用反向代理规范化后的 {@code X-Real-IP}，
     * 其次从 {@code X-Forwarded-For} 取第一个 IP，最后回退到连接地址。
     *
     * @param request HTTP 请求
     * @return 客户端 IP 地址
     */
    public static String getClientIp(HttpServletRequest request) {
        String realIp = request.getHeader("X-Real-IP");
        if (realIp != null && !realIp.isBlank()) {
            return realIp.trim();
        }
        String xff = request.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isBlank()) {
            return xff.split(",")[0].trim();
        }
        return request.getRemoteAddr();
    }
}
