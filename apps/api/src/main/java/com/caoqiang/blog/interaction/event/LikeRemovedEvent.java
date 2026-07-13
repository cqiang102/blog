package com.caoqiang.blog.interaction.event;

import com.caoqiang.blog.shared.domain.model.DomainEvent;
import java.util.UUID;

/**
 * 点赞移除事件
 * <p>
 * 当用户取消对内容的点赞时发布此事件。
 * 包含内容和用户的信息，可用于：
 * <ul>
 *   <li>更新内容热度排名</li>
 *   <li>记录用户行为日志</li>
 * </ul>
 */
public class LikeRemovedEvent extends DomainEvent {

    /** 被取消点赞的内容 ID */
    private final UUID contentId;

    /** 取消点赞的用户 ID */
    private final UUID userId;

    /**
     * 创建点赞移除事件
     *
     * @param contentId 内容 ID
     * @param userId    用户 ID
     */
    public LikeRemovedEvent(UUID contentId, UUID userId) {
        this.contentId = contentId;
        this.userId = userId;
    }

    public UUID getContentId() {
        return contentId;
    }

    public UUID getUserId() {
        return userId;
    }
}
