package com.caoqiang.blog.audit.domain.model;

/**
 * 审计操作类型枚举
 * <p>
 * 定义审计日志记录的操作类型。位于领域模型层，用于标准化审计日志中的操作类型字段。
 * </p>
 * <p>
 * 操作说明：
 * <ul>
 *   <li>{@link #CREATE} - 创建操作</li>
 *   <li>{@link #UPDATE} - 更新操作</li>
 *   <li>{@link #DELETE} - 删除操作</li>
 *   <li>{@link #READ} - 读取操作</li>
 * </ul>
 * </p>
 */
public enum AuditAction {
    /** 创建操作 */
    CREATE,
    /** 更新操作 */
    UPDATE,
    /** 删除操作 */
    DELETE,
    /** 读取操作 */
    READ;

    /**
     * 根据方法名推断操作类型
     * <p>
     * 根据方法名前缀自动识别操作类型：
     * <ul>
     *   <li>create/add/upload -> CREATE</li>
     *   <li>update/edit/set/change -> UPDATE</li>
     *   <li>delete/remove/softDelete -> DELETE</li>
     *   <li>get/list/detail/likes/views -> READ</li>
     *   <li>其他管理操作 -> UPDATE，保证新增方法不会因枚举转换失败而漏记审计日志</li>
     * </ul>
     *
     * @param methodName 方法名
     * @return 操作类型枚举值
     */
    public static AuditAction fromMethodName(String methodName) {
        if (methodName.startsWith("create") || methodName.startsWith("add") || methodName.startsWith("upload")) {
            return CREATE;
        }
        if (methodName.startsWith("delete") || methodName.startsWith("remove") || methodName.startsWith("softDelete")) {
            return DELETE;
        }
        if (methodName.startsWith("get")
                || methodName.startsWith("list")
                || methodName.startsWith("detail")
                || methodName.endsWith("Status")
                || methodName.equals("likes")
                || methodName.equals("views")) {
            return READ;
        }
        return UPDATE;
    }
}
