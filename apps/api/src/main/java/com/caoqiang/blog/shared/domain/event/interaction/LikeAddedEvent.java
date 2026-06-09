package com.caoqiang.blog.shared.domain.event.interaction;

import com.caoqiang.blog.shared.domain.model.DomainEvent;
import java.util.UUID;

/**
 * 点赞添加事件
 * <p>
 * 当用户对内容点赞时发布此事件。
 * 包含内容和用户的信息，可用于：
 * <ul>
 *   <li>通知内容作者</li>
 *   <li>更新内容热度排名</li>
 *   <li>记录用户行为日志</li>
 * </ul>
 */
public class LikeAddedEvent extends DomainEvent {

    /** 被点赞的内容 ID */
    private final UUID contentId;

    /** 点赞用户 ID */
    private final UUID userId;

    /**
     * 创建点赞添加事件
     *
     * @param contentId 内容 ID
     * @param userId    用户 ID
     */
    public LikeAddedEvent(UUID contentId, UUID userId) {
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
