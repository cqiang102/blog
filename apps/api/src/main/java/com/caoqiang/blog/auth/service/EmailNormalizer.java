package com.caoqiang.blog.auth.service;

import java.util.Locale;

/**
 * 邮箱规范化工具
 * 提供邮箱地址的规范化处理，确保邮箱地址的一致性和唯一性。
 * 位于博客系统的认证模块，是邮箱处理的核心工具类。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>空白处理 - 去除邮箱地址前后的空白字符</li>
 *   <li>大小写统一 - 将邮箱地址转换为小写，避免大小写敏感问题</li>
 *   <li>空值安全 - 处理 null 值，返回空字符串</li>
 *   <li>不可变性 - 工具类，不包含状态，所有方法都是静态的</li>
 * </ul>
 *
 * <p>规范化规则：</p>
 * <ol>
 *   <li>如果邮箱为 null，返回空字符串</li>
 *   <li>去除邮箱地址前后的空白字符</li>
 *   <li>将邮箱地址转换为小写</li>
 * </ol>
 *
 * <p>使用场景：</p>
 * <ul>
 *   <li>用户注册 - 规范化注册邮箱，确保唯一性</li>
 *   <li>用户登录 - 规范化登录邮箱，便于查找</li>
 *   <li>邮箱比较 - 规范化后进行邮箱比较，避免大小写差异</li>
 * </ul>
 *
 * @author blog-mimo
 */
public final class EmailNormalizer {

    /**
     * 私有构造函数，防止实例化
     */
    private EmailNormalizer() {
    }

    /**
     * 规范化邮箱地址
     * 将邮箱地址转换为小写并去除空白字符，确保一致性和唯一性。
     *
     * @param email 原始邮箱地址
     * @return 规范化后的邮箱地址，如果输入为 null 则返回空字符串
     */
    public static String normalize(String email) {
        return email == null ? "" : email.trim().toLowerCase(Locale.ROOT);
    }
}
