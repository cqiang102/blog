package com.caoqiang.blog.content;

import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.config.CacheNames;
import com.caoqiang.blog.content.application.event.ContentCacheEventListener;
import com.caoqiang.blog.content.event.ContentArchivedEvent;
import com.caoqiang.blog.content.event.ContentPublishedEvent;
import com.caoqiang.blog.interaction.event.LikeAddedEvent;
import com.caoqiang.blog.interaction.event.LikeRemovedEvent;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.cache.Cache;
import org.springframework.cache.CacheManager;

@ExtendWith(MockitoExtension.class)
class ContentCacheEventListenerTest {

    @Mock
    private CacheManager cacheManager;

    @Mock
    private Cache recommendationsCache;

    @Test
    void contentAndLikeEventsEvictRecommendations() {
        UUID contentId = UUID.randomUUID();
        UUID userId = UUID.randomUUID();
        ContentCacheEventListener listener = new ContentCacheEventListener(cacheManager);
        when(cacheManager.getCache(CacheNames.RECOMMENDATIONS)).thenReturn(recommendationsCache);

        listener.onContentPublished(new ContentPublishedEvent(contentId, "Title", "title"));
        listener.onContentArchived(new ContentArchivedEvent(contentId));
        listener.onLikeAdded(new LikeAddedEvent(contentId, userId));
        listener.onLikeRemoved(new LikeRemovedEvent(contentId, userId));

        verify(recommendationsCache, times(4)).clear();
    }
}
