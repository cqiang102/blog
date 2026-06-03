package com.caoqiang.blog.interaction;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 评论请求 DTO（数据传输对象）
 * <p>
 * 用于接收前端提交的评论数据。位于 API 层，使用 Java Record 实现不可变数据结构。
 * </p>
 * <p>
 * 验证规则：
 * <ul>
 *   <li>body 不能为空</li>
 *   <libody 长度不能超过 2000 字符</li>
 * </ul>
 * </p>
 *
 * @param body 评论内容，不能为空，最大长度 2000 字符
 */
public record CommentRequest(@NotBlank @Size(max = 2000) String body) {
}
