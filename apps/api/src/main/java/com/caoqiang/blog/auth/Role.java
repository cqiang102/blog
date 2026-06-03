package com.caoqiang.blog.auth;

/**
 * 角色枚举
 * 定义系统中的用户角色，用于权限控制和访问管理。
 * 位于博客系统的认证模块，是权限管理的核心组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>角色标识 - 使用枚举常量标识不同的用户角色</li>
 *   <li>类型安全 - 使用枚举确保类型安全，避免字符串硬编码</li>
 *   <li>权限控制 - 与 Spring Security 集成，实现基于角色的访问控制</li>
 * </ul>
 *
 * <p>角色说明：</p>
 * <ul>
 *   <li>USER - 普通用户，具有基本的博客操作权限</li>
 *   <li>ADMIN - 管理员，具有所有权限，包括用户管理、内容管理等</li>
 * </ul>
 *
 * <p>使用场景：</p>
 * <ul>
 *   <li>用户注册 - 默认分配 USER 角色</li>
 *   <li>权限检查 - 根据角色判断用户是否有权限执行操作</li>
 *   <li>JWT 令牌 - 在 JWT 令牌中包含用户角色信息</li>
 *   <li>安全配置 - 在 Spring Security 配置中使用角色进行访问控制</li>
 * </ul>
 *
 * @author blog-mimo
 */
public enum Role {
    /** 普通用户角色 */
    USER,
    /** 管理员角色 */
    ADMIN
}
