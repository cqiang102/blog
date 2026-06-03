package com.caoqiang.blog.common;

import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.servlet.NoHandlerFoundException;

/**
 * 全局异常处理器。
 * <p>
 * 通过 {@code @RestControllerAdvice} 统一拦截 Controller 层抛出的异常，
 * 将其转换为标准的 {@link ApiResponse} 格式返回，避免将异常堆栈暴露给客户端。
 * <p>
 * 处理策略：
 * <ul>
 *     <li>{@link BusinessException} — 业务异常，使用异常中携带的 HTTP 状态码</li>
 *     <li>{@link MethodArgumentNotValidException} / {@link ConstraintViolationException} — 参数校验失败，返回 400</li>
 *     <li>{@link HttpMessageNotReadableException} — 请求体格式错误，返回 400</li>
 *     <li>{@link MissingServletRequestParameterException} — 缺少请求参数，返回 400</li>
 *     <li>{@link HttpRequestMethodNotSupportedException} — HTTP 方法不支持，返回 405</li>
 *     <li>{@link NoHandlerFoundException} — 路径不存在，返回 404</li>
 *     <li>{@link Exception} — 未知异常，返回 500，隐藏内部错误细节</li>
 * </ul>
 *
 * @author caoqiang
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    /**
     * 处理业务异常。
     *
     * @param exception 业务异常实例
     * @return 包含错误信息的 ApiResponse 响应
     */
    @ExceptionHandler(BusinessException.class)
    public ResponseEntity<ApiResponse<Void>> handleBusinessException(BusinessException exception) {
        return ResponseEntity.status(exception.status()).body(ApiResponse.fail(exception.getMessage()));
    }

    /**
     * 处理参数校验异常（@Valid 和 @Validated 触发的校验失败）。
     *
     * @param exception 参数校验异常
     * @return 400 Bad Request 响应
     */
    @ExceptionHandler({MethodArgumentNotValidException.class, ConstraintViolationException.class})
    public ResponseEntity<ApiResponse<Void>> handleValidationException(Exception exception) {
        return ResponseEntity.badRequest().body(ApiResponse.fail("请求参数不合法"));
    }

    /**
     * 处理请求体格式错误（如 JSON 语法错误）。
     *
     * @param exception 请求体不可读异常
     * @return 400 Bad Request 响应
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiResponse<Void>> handleBadRequest(HttpMessageNotReadableException exception) {
        return ResponseEntity.badRequest().body(ApiResponse.fail("请求体格式错误"));
    }

    /**
     * 处理缺少请求参数。
     *
     * @param exception 缺少请求参数异常
     * @return 400 Bad Request 响应
     */
    @ExceptionHandler(MissingServletRequestParameterException.class)
    public ResponseEntity<ApiResponse<Void>> handleMissingParam(MissingServletRequestParameterException exception) {
        return ResponseEntity.badRequest().body(ApiResponse.fail("缺少请求参数: " + exception.getParameterName()));
    }

    /**
     * 处理 HTTP 方法不支持。
     *
     * @param exception HTTP 方法不支持异常
     * @return 405 Method Not Allowed 响应
     */
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    public ResponseEntity<ApiResponse<Void>> handleMethodNotAllowed(HttpRequestMethodNotSupportedException exception) {
        return ResponseEntity.status(HttpStatus.METHOD_NOT_ALLOWED).body(ApiResponse.fail("不支持的请求方法"));
    }

    /**
     * 处理路径不存在。
     *
     * @param exception 无处理器异常
     * @return 404 Not Found 响应
     */
    @ExceptionHandler(NoHandlerFoundException.class)
    public ResponseEntity<ApiResponse<Void>> handleNotFound(NoHandlerFoundException exception) {
        return ResponseEntity.status(HttpStatus.NOT_FOUND).body(ApiResponse.fail("接口不存在"));
    }

    /**
     * 兜底处理所有未预期的异常，避免泄露内部错误信息。
     *
     * @param exception 未知异常
     * @return 500 Internal Server Error 响应
     */
    @ExceptionHandler(Exception.class)
    public ResponseEntity<ApiResponse<Void>> handleUnexpectedException(Exception exception) {
        log.error("Unexpected exception: {}", exception.getMessage(), exception);
        return ResponseEntity.status(HttpStatus.INTERNAL_SERVER_ERROR).body(ApiResponse.fail("服务暂时不可用"));
    }
}
