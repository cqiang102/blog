package com.caoqiang.blog.interaction.application.dto;

import java.util.UUID;

/**
 * 浏览状态响应 DTO（数据传输对象）
 * <p>
 * 用于向前端返回浏览记录操作的结果。位于 API 层，使用 Java Record 实现不可变数据结构。
 * </p>
 * <p>
 * 包含内容 ID、是否为新浏览和总浏览数。
 * </p>
 *
 * @param contentId 内容 ID
 * @param recorded  是否成功记录浏览（新浏览为 true，重复浏览为 false）
 * @param viewCount 内容的总浏览数
 */
public record ViewStateResponse(UUID contentId, boolean recorded, long viewCount) {}
