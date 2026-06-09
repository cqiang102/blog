package com.caoqiang.blog.shared.domain.event.interaction;

import com.caoqiang.blog.shared.domain.model.DomainEvent;
import java.util.UUID;

/**
 * 评论创建事件
 * <p>
 * 当用户对内容发表评论时发布此事件。
 * 包含评论、内容和用户的信息，可用于：
 * <ul>
 *   <li>通知内容作者有新评论</li>
 *   <li>触发 AI 内容审核</li>
 *   <li>更新内容评论计数</li>
 *   <li>记录审计日志</li>
 * </ul>
 */
public class CommentCreatedEvent extends DomainEvent {

    /** 评论 ID */
    private final UUID commentId;

    /** 被评论的内容 ID */
    private final UUID contentId;

    /** 评论作者 ID */
    private final UUID userId;

    /**
     * 创建评论创建事件
     *
     * @param commentId 评论 ID
     * @param contentId 内容 ID
     * @param userId    用户 ID
     */
    public CommentCreatedEvent(UUID commentId, UUID contentId, UUID userId) {
        this.commentId = commentId;
        this.contentId = contentId;
        this.userId = userId;
    }

    public UUID getCommentId() {
        return commentId;
    }

    public UUID getContentId() {
        return contentId;
    }

    public UUID getUserId() {
        return userId;
    }
}
