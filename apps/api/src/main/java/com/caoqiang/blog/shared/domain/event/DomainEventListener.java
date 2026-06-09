package com.caoqiang.blog.shared.domain.event;

import com.caoqiang.blog.shared.domain.event.content.ContentArchivedEvent;
import com.caoqiang.blog.shared.domain.event.content.ContentPublishedEvent;
import com.caoqiang.blog.shared.domain.event.interaction.CommentCreatedEvent;
import com.caoqiang.blog.shared.domain.event.interaction.LikeAddedEvent;
import com.caoqiang.blog.shared.domain.event.user.UserCreatedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.annotation.CacheEvict;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

/**
 * 领域事件监听器
 * <p>
 * 集中处理各类领域事件的监听和响应。
 * 通过 Spring 的 {@link EventListener} 机制实现事件驱动架构。
 * <p>
 * 事件处理策略：
 * <ul>
 *   <li>缓存相关事件（ContentPublished, ContentArchived）- 同步清除推荐缓存</li>
 *   <li>日志相关事件（UserCreated, CommentCreated, LikeAdded）- 异步记录日志</li>
 * </ul>
 * <p>
 * 扩展点：
 * <ul>
 *   <li>可添加通知服务（如邮件、站内信）</li>
 *   <li>可添加审计日志服务</li>
 *   <li>可添加数据分析服务</li>
 * </ul>
 */
@Component
public class DomainEventListener {

    private static final Logger log = LoggerFactory.getLogger(DomainEventListener.class);

    /**
     * 处理用户创建事件
     * <p>
     * 异步记录用户注册日志，可用于后续的通知服务扩展。
     *
     * @param event 用户创建事件
     */
    @EventListener
    @Async
    public void onUserCreated(UserCreatedEvent event) {
        log.info("User created: id={}, email={}, nickname={}", 
                event.getUserId(), event.getEmail(), event.getNickname());
    }

    /**
     * 处理内容发布事件
     * <p>
     * 同步清除推荐缓存，确保推荐列表数据一致性。
     *
     * @param event 内容发布事件
     */
    @EventListener
    @CacheEvict(value = "recommendations", allEntries = true)
    public void onContentPublished(ContentPublishedEvent event) {
        log.info("Content published: id={}, title={}, slug={}", 
                event.getContentId(), event.getTitle(), event.getSlug());
    }

    /**
     * 处理内容归档事件
     * <p>
     * 同步清除推荐缓存，确保推荐列表数据一致性。
     *
     * @param event 内容归档事件
     */
    @EventListener
    @CacheEvict(value = "recommendations", allEntries = true)
    public void onContentArchived(ContentArchivedEvent event) {
        log.info("Content archived: id={}", event.getContentId());
    }

    /**
     * 处理评论创建事件
     * <p>
     * 异步记录评论日志，可用于通知内容作者。
     *
     * @param event 评论创建事件
     */
    @EventListener
    @Async
    public void onCommentCreated(CommentCreatedEvent event) {
        log.info("Comment created: commentId={}, contentId={}, userId={}", 
                event.getCommentId(), event.getContentId(), event.getUserId());
    }

    /**
     * 处理点赞添加事件
     * <p>
     * 异步记录点赞日志，可用于数据分析。
     *
     * @param event 点赞添加事件
     */
    @EventListener
    @Async
    public void onLikeAdded(LikeAddedEvent event) {
        log.info("Like added: contentId={}, userId={}", 
                event.getContentId(), event.getUserId());
    }
}
