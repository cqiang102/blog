package com.caoqiang.blog.shared.model;

/**
 * 角色枚举
 * 定义系统中的用户角色，用于权限控制和访问管理。
 *
 * <p>角色说明：</p>
 * <ul>
 *   <li>USER - 普通用户，具有基本的博客操作权限</li>
 *   <li>ADMIN - 管理员，具有所有权限，包括用户管理、内容管理等</li>
 * </ul>
 */
public enum Role {
    /** 普通用户角色 */
    USER,
    /** 管理员角色 */
    ADMIN
}
