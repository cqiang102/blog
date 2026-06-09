package com.caoqiang.blog.shared.domain.event.content;

import com.caoqiang.blog.shared.domain.model.DomainEvent;
import java.util.UUID;

/**
 * 内容发布事件
 * <p>
 * 当内容状态变更为已发布时发布此事件。
 * 包含内容的基本信息，可用于：
 * <ul>
 *   <li>清除推荐缓存</li>
 *   <li>更新搜索引擎索引</li>
 *   <li>通知关注者</li>
 *   <li>同步知识库</li>
 * </ul>
 */
public class ContentPublishedEvent extends DomainEvent {

    /** 内容 ID */
    private final UUID contentId;

    /** 内容标题 */
    private final String title;

    /** 内容 slug（URL 标识符） */
    private final String slug;

    /**
     * 创建内容发布事件
     *
     * @param contentId 内容 ID
     * @param title     内容标题
     * @param slug      内容 slug
     */
    public ContentPublishedEvent(UUID contentId, String title, String slug) {
        this.contentId = contentId;
        this.title = title;
        this.slug = slug;
    }

    public UUID getContentId() {
        return contentId;
    }

    public String getTitle() {
        return title;
    }

    public String getSlug() {
        return slug;
    }
}
