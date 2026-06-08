package com.caoqiang.blog.shared.util;

import java.util.Locale;
import java.util.UUID;

/**
 * URL Slug 生成工具类。
 * <p>
 * 将中文标题或任意文本转换为 URL 友好的 slug 字符串，用于文章、页面等资源的 URL 路径。
 * <p>
 * 处理规则：
 * <ul>
 *     <li>转小写并去除首尾空白</li>
 *     <li>保留英文字母、数字和中文字符，其余字符替换为连字符 {@code -}</li>
 *     <li>去除首尾连字符，合并连续连字符</li>
 *     <li>空内容回退为随机 UUID</li>
 *     <li>最大长度限制 80 字符，超出时截断并去除尾部连字符</li>
 * </ul>
 * <p>
 * 示例：
 * <pre>
 * SlugUtils.from("Hello World")        → "hello-world"
 * SlugUtils.from("Spring Boot 入门指南") → "spring-boot-入门指南"
 * SlugUtils.from("")                   → "随机 UUID"
 * </pre>
 *
 * @author caoqiang
 */
public final class SlugUtils {

    /** 工具类，禁止实例化 */
    private SlugUtils() {
    }

    /**
     * 将输入文本转换为 URL 友好的 slug。
     *
     * @param value 原始文本（可为 null）
     * @return 生成的 slug 字符串，保证非空且长度不超过 80
     */
    public static String from(String value) {
        String slug = value == null ? "" : value.trim().toLowerCase(Locale.ROOT)
                .replaceAll("[^a-z0-9\\u4e00-\\u9fa5]+", "-") // 非字母数字中文替换为连字符
                .replaceAll("(^-+|-+$)", "");                  // 去除首尾连字符
        if (slug.isBlank()) {
            return UUID.randomUUID().toString(); // 空内容回退为 UUID
        }
        return slug.length() > 80 ? slug.substring(0, 80).replaceAll("-+$", "") : slug;
    }
}
