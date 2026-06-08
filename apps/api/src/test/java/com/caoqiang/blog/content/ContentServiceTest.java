package com.caoqiang.blog.content;

import com.caoqiang.blog.content.dto.ContentDetailResponse;
import com.caoqiang.blog.content.dto.ContentSummaryResponse;
import com.caoqiang.blog.content.dto.RecommendationResponse;
import com.caoqiang.blog.content.entity.Content;
import com.caoqiang.blog.content.entity.ContentStatus;
import com.caoqiang.blog.content.entity.ContentType;
import com.caoqiang.blog.content.repository.ContentRepository;
import com.caoqiang.blog.content.service.ContentService;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.interaction.repository.LikeRepository;
import java.time.Instant;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;

@ExtendWith(MockitoExtension.class)
class ContentServiceTest {

    @Mock
    private ContentRepository contentRepository;

    @Mock
    private LikeRepository likeRepository;

    @InjectMocks
    private ContentService contentService;

    private Content publishedContent;
    private UUID contentId;

    @BeforeEach
    void setUp() {
        contentId = UUID.randomUUID();
        publishedContent = new Content(
                "Test Article",
                "test-article",
                ContentType.ARTICLE,
                ContentStatus.PUBLISHED,
                "Test summary",
                "# Test Body",
                false,
                Instant.now(),
                Set.of()
        );
    }

    @Test
    void recommendations_returnsThreeLists() {
        when(contentRepository.findTop10ByStatusAndPinnedTrueAndPublishedAtIsNotNullOrderByPublishedAtDesc(any()))
                .thenReturn(List.of(publishedContent));
        when(contentRepository.findTop10ByStatusAndPublishedAtIsNotNullOrderByPublishedAtDesc(any()))
                .thenReturn(List.of(publishedContent));
        when(contentRepository.findTop10ByStatusAndPublishedAtIsNotNullOrderByLikeCountDescPublishedAtDesc(any()))
                .thenReturn(List.of(publishedContent));

        RecommendationResponse response = contentService.recommendations();

        assertNotNull(response);
        assertEquals(1, response.pinned().size());
        assertEquals(1, response.latest().size());
        assertEquals(1, response.mostLiked().size());
    }

    @Test
    void list_returnsPaginatedResults() {
        Page<Content> page = new PageImpl<>(List.of(publishedContent));
        when(contentRepository.findAll(any(org.springframework.data.jpa.domain.Specification.class), any(Pageable.class)))
                .thenReturn(page);

        PageResponse<ContentSummaryResponse> result = contentService.list(
                "test", null, null, null, null, 0, 10
        );

        assertNotNull(result);
        assertEquals(1, result.items().size());
        assertEquals("Test Article", result.items().get(0).title());
    }

    @Test
    void detail_returnsContentWithLikeStatus() {
        when(contentRepository.findByIdAndStatus(eq(contentId), eq(ContentStatus.PUBLISHED)))
                .thenReturn(Optional.of(publishedContent));
        when(likeRepository.existsByContentIdAndUserId(eq(contentId), any(UUID.class)))
                .thenReturn(true);

        AuthenticatedUser user = new AuthenticatedUser(UUID.randomUUID(), "test@example.com", "Test", Role.USER);
        ContentDetailResponse detail = contentService.detail(contentId, user);

        assertNotNull(detail);
        assertEquals("Test Article", detail.title());
        assertTrue(detail.likedByCurrentUser());
    }

    @Test
    void detail_returnsContentWithoutLikeForAnonymous() {
        when(contentRepository.findByIdAndStatus(eq(contentId), eq(ContentStatus.PUBLISHED)))
                .thenReturn(Optional.of(publishedContent));

        ContentDetailResponse detail = contentService.detail(contentId, null);

        assertNotNull(detail);
        assertFalse(detail.likedByCurrentUser());
    }
}
