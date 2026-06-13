package com.caoqiang.blog.shared.response;

import java.util.UUID;

/**
 * 通用操作结果响应 DTO。
 * <p>
 * 用于 Controller 返回简单的操作结果，替代 {@code Map<String, Object>}。
 * 提供多种静态工厂方法，方便快速创建常见操作结果。
 *
 * @param success   操作是否成功
 * @param message   操作结果消息
 * @param id        相关资源 ID（可选）
 * @param resourceId 相关资源 ID 的字符串形式（可选）
 */
public record OperationResult(
        boolean success,
        String message,
        UUID id,
        String resourceId
) {

    /**
     * 创建成功的删除操作结果。
     *
     * @param id 被删除资源的 ID
     * @return 操作结果
     */
    public static OperationResult deleted(UUID id) {
        return new OperationResult(true, "删除成功", id, id.toString());
    }

    /**
     * 创建成功的归档操作结果。
     *
     * @param id 被归档资源的 ID
     * @return 操作结果
     */
    public static OperationResult archived(UUID id) {
        return new OperationResult(true, "归档成功", id, id.toString());
    }

    /**
     * 创建成功的更新操作结果。
     *
     * @param id 被更新资源的 ID
     * @return 操作结果
     */
    public static OperationResult updated(UUID id) {
        return new OperationResult(true, "更新成功", id, id.toString());
    }

    /**
     * 创建成功的创建操作结果。
     *
     * @param id 新创建资源的 ID
     * @return 操作结果
     */
    public static OperationResult created(UUID id) {
        return new OperationResult(true, "创建成功", id, id.toString());
    }

    /**
     * 创建成功的恢复操作结果。
     *
     * @param id 被恢复资源的 ID
     * @return 操作结果
     */
    public static OperationResult restored(UUID id) {
        return new OperationResult(true, "恢复成功", id, id.toString());
    }

    /**
     * 创建带自定义消息的成功操作结果。
     *
     * @param message 自定义消息
     * @param id      相关资源 ID
     * @return 操作结果
     */
    public static OperationResult success(String message, UUID id) {
        return new OperationResult(true, message, id, id != null ? id.toString() : null);
    }

    /**
     * 创建不带资源 ID 的成功操作结果。
     *
     * @param message 操作消息
     * @return 操作结果
     */
    public static OperationResult success(String message) {
        return new OperationResult(true, message, null, null);
    }
}
