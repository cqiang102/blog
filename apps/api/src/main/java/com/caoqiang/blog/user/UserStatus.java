package com.caoqiang.blog.user;

/**
 * 用户状态枚举
 * <p>
 * 定义用户账户的两种状态：
 * <ul>
 *   <li>{@link #ACTIVE} - 活跃状态，用户可以正常登录和使用系统</li>
 *   <li>{@link #DISABLED} - 禁用状态，用户无法登录，通常由管理员操作</li>
 * </ul>
 */
public enum UserStatus {
    /** 活跃状态，用户可正常登录 */
    ACTIVE,
    /** 禁用状态，用户无法登录 */
    DISABLED
}
