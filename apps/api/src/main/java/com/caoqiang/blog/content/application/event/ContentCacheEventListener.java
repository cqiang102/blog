package com.caoqiang.blog.content.application.event;

import com.caoqiang.blog.config.CacheNames;
import com.caoqiang.blog.content.event.ContentArchivedEvent;
import com.caoqiang.blog.content.event.ContentPublishedEvent;
import com.caoqiang.blog.interaction.event.LikeAddedEvent;
import com.caoqiang.blog.interaction.event.LikeRemovedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.CacheManager;
import org.springframework.context.event.EventListener;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Owns recommendation-cache reactions for events consumed by the content module.
 */
@Component
public class ContentCacheEventListener {

    private static final Logger log = LoggerFactory.getLogger(ContentCacheEventListener.class);

    private final CacheManager cacheManager;

    public ContentCacheEventListener(CacheManager cacheManager) {
        this.cacheManager = cacheManager;
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onContentPublished(ContentPublishedEvent event) {
        log.info("Content published: id={}, title={}, slug={}",
                event.getContentId(), event.getTitle(), event.getSlug());
        evictRecommendationsCache();
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onContentArchived(ContentArchivedEvent event) {
        log.info("Content archived: id={}", event.getContentId());
        evictRecommendationsCache();
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onLikeAdded(LikeAddedEvent event) {
        log.info("Like added: contentId={}, userId={}",
                event.getContentId(), event.getUserId());
        evictRecommendationsCache();
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onLikeRemoved(LikeRemovedEvent event) {
        log.info("Like removed: contentId={}, userId={}",
                event.getContentId(), event.getUserId());
        evictRecommendationsCache();
    }

    private void evictRecommendationsCache() {
        var cache = cacheManager.getCache(CacheNames.RECOMMENDATIONS);
        if (cache != null) {
            cache.clear();
        }
    }
}
