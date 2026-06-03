package com.caoqiang.blog.common;

import org.springframework.http.HttpStatus;

/**
 * 自定义业务异常类。
 * <p>
 * 用于在业务逻辑中抛出带有明确 HTTP 状态码的异常，由 {@link GlobalExceptionHandler}
 * 统一捕获并转换为标准的 {@link ApiResponse} 格式返回给客户端。
 * <p>
 * 使用示例：
 * <pre>
 * throw new BusinessException(HttpStatus.NOT_FOUND, "文章不存在");
 * throw new BusinessException(HttpStatus.FORBIDDEN, "无权操作");
 * </pre>
 *
 * @author caoqiang
 */
public class BusinessException extends RuntimeException {

    private final HttpStatus status; // HTTP 响应状态码

    /**
     * 构造业务异常。
     *
     * @param status  HTTP 状态码（如 404、403、400 等）
     * @param message 错误描述信息
     */
    public BusinessException(HttpStatus status, String message) {
        super(message);
        this.status = status;
    }

    /**
     * 获取异常对应的 HTTP 状态码。
     *
     * @return HTTP 状态码枚举
     */
    public HttpStatus status() {
        return status;
    }
}
