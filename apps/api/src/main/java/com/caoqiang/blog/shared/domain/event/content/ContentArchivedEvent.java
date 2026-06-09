package com.caoqiang.blog.shared.domain.event.content;

import com.caoqiang.blog.shared.domain.model.DomainEvent;
import java.util.UUID;

/**
 * 内容归档事件
 * <p>
 * 当内容状态变更为归档时发布此事件。
 * 包含内容 ID，可用于：
 * <ul>
 *   <li>清除推荐缓存</li>
 *   <li>删除搜索引擎索引</li>
 *   <li>清理知识库向量</li>
 * </ul>
 */
public class ContentArchivedEvent extends DomainEvent {

    /** 内容 ID */
    private final UUID contentId;

    /**
     * 创建内容归档事件
     *
     * @param contentId 内容 ID
     */
    public ContentArchivedEvent(UUID contentId) {
        this.contentId = contentId;
    }

    public UUID getContentId() {
        return contentId;
    }
}
