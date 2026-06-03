package com.caoqiang.blog.common;

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
     * 优先从 {@code X-Forwarded-For} 头部取第一个 IP（经过多级代理时），
     * 其次取 {@code X-Real-IP}，最后回退到 {@code getRemoteAddr()}。
     *
     * @param request HTTP 请求
     * @return 客户端 IP 地址
     */
    public static String getClientIp(HttpServletRequest request) {
        String xff = request.getHeader("X-Forwarded-For");
        if (xff != null && !xff.isEmpty()) {
            return xff.split(",")[0].trim();
        }
        String realIp = request.getHeader("X-Real-IP");
        if (realIp != null && !realIp.isEmpty()) {
            return realIp;
        }
        return request.getRemoteAddr();
    }
}
