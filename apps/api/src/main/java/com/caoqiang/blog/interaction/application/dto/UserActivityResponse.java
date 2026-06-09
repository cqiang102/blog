package com.caoqiang.blog.interaction.application.dto;

import com.caoqiang.blog.interaction.domain.model.Comment;
import com.caoqiang.blog.interaction.domain.model.CommentStatus;
import com.caoqiang.blog.interaction.domain.model.Like;
import com.caoqiang.blog.interaction.domain.model.ViewRecord;

import com.caoqiang.blog.content.domain.model.Content;
import java.time.Instant;
import java.util.UUID;

/**
 * 用户活动响应 DTO（数据传输对象）
 * <p>
 * 用于向前端返回用户的互动活动记录（评论、点赞、浏览）。位于 API 层，使用 Java Record 实现不可变数据结构。
 * </p>
 * <p>
 * 包含活动 ID、活动类型、关联内容信息和创建时间。
 * 提供工厂方法用于创建不同类型的活动记录。
 * </p>
 *
 * @param id        活动记录 ID
 * @param type      活动类型（COMMENT/LIKE/VIEW）
 * @param contentId 关联内容 ID
 * @param title     关联内容标题
 * @param createdAt 创建时间
 */
public record UserActivityResponse(
        UUID id,
        String type,
        UUID contentId,
        String title,
        Instant createdAt
) {

    /**
     * 创建评论类型的用户活动响应
     *
     * @param id        评论 ID
     * @param content   关联内容
     * @param createdAt 创建时间
     * @return 用户活动响应
     */
    public static UserActivityResponse comment(UUID id, Content content, Instant createdAt) {
        return new UserActivityResponse(id, "COMMENT", content.getId(), content.getTitle(), createdAt);
    }

    /**
     * 创建点赞类型的用户活动响应
     *
     * @param content   关联内容
     * @param createdAt 创建时间
     * @return 用户活动响应
     */
    public static UserActivityResponse like(Content content, Instant createdAt) {
        return new UserActivityResponse(content.getId(), "LIKE", content.getId(), content.getTitle(), createdAt);
    }

    /**
     * 创建浏览类型的用户活动响应
     *
     * @param id        浏览记录 ID
     * @param content   关联内容
     * @param createdAt 创建时间
     * @return 用户活动响应
     */
    public static UserActivityResponse view(UUID id, Content content, Instant createdAt) {
        return new UserActivityResponse(id, "VIEW", content.getId(), content.getTitle(), createdAt);
    }
}
