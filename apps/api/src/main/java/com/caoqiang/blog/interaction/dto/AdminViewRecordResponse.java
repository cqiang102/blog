package com.caoqiang.blog.interaction.dto;

import com.caoqiang.blog.interaction.entity.Comment;
import com.caoqiang.blog.interaction.entity.CommentStatus;
import com.caoqiang.blog.interaction.entity.Like;
import com.caoqiang.blog.interaction.entity.ViewRecord;

import com.caoqiang.blog.user.entity.User;
import java.time.Instant;
import java.util.UUID;

/**
 * 管理端浏览记录响应 DTO（数据传输对象）
 * <p>
 * 用于向前端管理界面返回浏览记录数据。位于 API 层，使用 Java Record 实现不可变数据结构。
 * </p>
 * <p>
 * 包含浏览记录的详细信息，包括关联内容、用户信息（可选）、匿名标识和客户端信息。
 * </p>
 *
 * @param id           浏览记录 ID
 * @param contentId    关联内容 ID
 * @param contentTitle 关联内容标题
 * @param userId       浏览用户 ID（匿名用户为 null）
 * @param userNickname 浏览用户昵称（匿名用户为 null）
 * @param userEmail    浏览用户邮箱（匿名用户为 null）
 * @param anonymousId  匿名用户 ID（已登录用户为 null）
 * @param ipHash       IP 地址哈希值
 * @param userAgent    User-Agent 字符串
 * @param createdAt    创建时间
 */
public record AdminViewRecordResponse(
        UUID id,
        UUID contentId,
        String contentTitle,
        UUID userId,
        String userNickname,
        String userEmail,
        String anonymousId,
        String ipHash,
        String userAgent,
        Instant createdAt
) {

    /**
     * 从浏览记录实体创建管理端响应 DTO
     *
     * @param viewRecord 浏览记录实体
     * @return 管理端浏览记录响应 DTO
     */
    public static AdminViewRecordResponse from(ViewRecord viewRecord) {
        User user = viewRecord.getUser();
        return new AdminViewRecordResponse(
                viewRecord.getId(),
                viewRecord.getContent().getId(),
                viewRecord.getContent().getTitle(),
                user == null ? null : user.getId(),
                user == null ? null : user.getNickname(),
                user == null ? null : user.getEmail(),
                viewRecord.getAnonymousId(),
                viewRecord.getIpHash(),
                viewRecord.getUserAgent(),
                viewRecord.getCreatedAt()
        );
    }
}
