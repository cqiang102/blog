package com.caoqiang.blog.shared.util;

import java.util.Locale;

/**
 * 邮箱规范化工具
 * <p>
 * 提供邮箱地址的规范化处理，确保邮箱地址的一致性和唯一性。
 * 位于共享工具层，被多个域使用（user, auth）。
 * <p>
 * 规范化规则：
 * <ul>
 *   <li>null 值处理 - 返回空字符串</li>
 *   <li>空白字符 - 去除前后空白</li>
 *   <li>大小写 - 统一转换为小写</li>
 * </ul>
 * <p>
 * 使用场景：
 * <ul>
 *   <li>用户注册 - 规范化注册邮箱，确保唯一性</li>
 *   <li>用户登录 - 规范化登录邮箱，便于查找</li>
 *   <li>邮箱比较 - 规范化后进行邮箱比较，避免大小写差异</li>
 * </ul>
 */
public final class EmailNormalizer {

    /** 私有构造函数，防止实例化 */
    private EmailNormalizer() {
    }

    /**
     * 规范化邮箱地址
     * <p>
     * 将邮箱地址转换为小写并去除空白字符，确保一致性和唯一性。
     *
     * @param email 原始邮箱地址
     * @return 规范化后的邮箱地址，如果输入为 null 则返回空字符串
     */
    public static String normalize(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }
}
