package com.caoqiang.blog.shared.response;

/**
 * 通用 API 响应封装 record。
 * <p>
 * 作为所有 REST 接口的统一返回格式，确保前端获得一致的响应结构：
 * <pre>
 * {
 *   "success": true/false,
 *   "data": { ... },
 *   "message": "ok" / "错误描述"
 * }
 * </pre>
 * <p>
 * 提供两个便捷静态工厂方法：{@link #ok(Object)} 和 {@link #fail(String)}。
 *
 * @param success 请求是否成功
 * @param data    响应数据，失败时为 null
 * @param message 响应消息，成功时默认为 "ok"
 * @param <T>     响应数据类型
 */
public record ApiResponse<T>(boolean success, T data, String message) {

    /**
     * 构造成功响应。
     *
     * @param data 响应数据
     * @param <T>  数据类型
     * @return 成功的 ApiResponse 实例
     */
    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(true, data, "ok");
    }

    /**
     * 构造失败响应。
     *
     * @param message 错误描述信息
     * @param <T>     数据类型
     * @return 失败的 ApiResponse 实例（data 为 null）
     */
    public static <T> ApiResponse<T> fail(String message) {
        return new ApiResponse<>(false, null, message);
    }
}
