package com.caoqiang.blog.content.application.event;

import com.caoqiang.blog.config.CacheNames;
import com.caoqiang.blog.content.event.ContentArchivedEvent;
import com.caoqiang.blog.content.event.ContentPublishedEvent;
import com.caoqiang.blog.interaction.event.LikeAddedEvent;
import com.caoqiang.blog.interaction.event.LikeRemovedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.cache.CacheManager;
import org.springframework.stereotype.Component;
import org.springframework.transaction.event.TransactionPhase;
import org.springframework.transaction.event.TransactionalEventListener;

/**
 * Owns recommendation and feed cache reactions for content lifecycle events.
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
        log.debug("Content published; evicting recommendations: contentId={}", event.getContentId());
        evictRecommendationsCache();
        evictFeedCache();
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onContentArchived(ContentArchivedEvent event) {
        log.debug("Content archived; evicting recommendations: contentId={}", event.getContentId());
        evictRecommendationsCache();
        evictFeedCache();
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onLikeAdded(LikeAddedEvent event) {
        log.debug("Like added; evicting recommendations: contentId={}", event.getContentId());
        evictRecommendationsCache();
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    public void onLikeRemoved(LikeRemovedEvent event) {
        log.debug("Like removed; evicting recommendations: contentId={}", event.getContentId());
        evictRecommendationsCache();
    }

    private void evictRecommendationsCache() {
        var cache = cacheManager.getCache(CacheNames.RECOMMENDATIONS);
        if (cache != null) {
            cache.clear();
        }
    }

    private void evictFeedCache() {
        var cache = cacheManager.getCache(CacheNames.ATOM_FEED);
        if (cache != null) {
            cache.clear();
        }
    }
}
