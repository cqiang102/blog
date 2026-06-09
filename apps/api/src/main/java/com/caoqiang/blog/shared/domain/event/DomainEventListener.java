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

@Component
public class DomainEventListener {

    private static final Logger log = LoggerFactory.getLogger(DomainEventListener.class);

    @EventListener
    @Async
    public void onUserCreated(UserCreatedEvent event) {
        log.info("User created: id={}, email={}, nickname={}", 
                event.getUserId(), event.getEmail(), event.getNickname());
    }

    @EventListener
    @CacheEvict(value = "recommendations", allEntries = true)
    public void onContentPublished(ContentPublishedEvent event) {
        log.info("Content published: id={}, title={}, slug={}", 
                event.getContentId(), event.getTitle(), event.getSlug());
    }

    @EventListener
    @CacheEvict(value = "recommendations", allEntries = true)
    public void onContentArchived(ContentArchivedEvent event) {
        log.info("Content archived: id={}", event.getContentId());
    }

    @EventListener
    @Async
    public void onCommentCreated(CommentCreatedEvent event) {
        log.info("Comment created: commentId={}, contentId={}, userId={}", 
                event.getCommentId(), event.getContentId(), event.getUserId());
    }

    @EventListener
    @Async
    public void onLikeAdded(LikeAddedEvent event) {
        log.info("Like added: contentId={}, userId={}", 
                event.getContentId(), event.getUserId());
    }
}
