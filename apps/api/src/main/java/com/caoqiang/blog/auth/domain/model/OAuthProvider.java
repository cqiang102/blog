package com.caoqiang.blog.auth.domain.model;

/**
 * OAuth 提供者枚举
 * 定义系统支持的 OAuth 第三方登录提供者。
 * 位于博客系统的认证模块，是 OAuth 认证流程的配置组件。
 *
 * <p>关键特性：</p>
 * <ul>
 *   <li>提供者标识 - 使用枚举常量标识不同的 OAuth 提供者</li>
 *   <li>类型安全 - 使用枚举确保类型安全，避免字符串硬编码</li>
 *   <li>可扩展性 - 可以方便地添加新的 OAuth 提供者</li>
 * </ul>
 *
 * <p>当前支持的提供者：</p>
 * <ul>
 *   <li>GITHUB - GitHub OAuth2 登录（已启用）</li>
 *   <li>QQ - QQ 互联登录（已预留，待实现）</li>
 * </ul>
 *
 * <p>使用场景：</p>
 * <ul>
 *   <li>OAuth 账户关联 - 标识用户关联的第三方账户类型</li>
 *   <li>登录流程 - 根据提供者类型选择对应的 OAuth2 处理逻辑</li>
 *   <li>配置管理 - 在配置文件中指定启用的 OAuth 提供者</li>
 * </ul>
 *
 * @author blog-mimo
 */
public enum OAuthProvider {
    /** GitHub OAuth2 登录 */
    GITHUB,
    /** QQ 互联登录（已预留，待实现） */
    QQ
}
