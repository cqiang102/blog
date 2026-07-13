package com.caoqiang.blog.content;

import com.caoqiang.blog.content.application.dto.ContentDetailResponse;
import com.caoqiang.blog.content.application.dto.ContentSummaryResponse;
import com.caoqiang.blog.content.application.dto.RecommendationResponse;
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.repository.MediaAssetRepository;
import com.caoqiang.blog.content.application.service.ContentQueryService;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.*;
import static org.mockito.Mockito.*;

import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.model.Role;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.interaction.application.api.InteractionStateService;
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
class ContentQueryServiceTest {

    @Mock
    private ContentRepository contentRepository;

    @Mock
    private InteractionStateService interactionStateService;

    @Mock
    private MediaAssetRepository mediaAssetRepository;

    @InjectMocks
    private ContentQueryService contentQueryService;

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
        when(contentRepository.findTop10ByStatusAndPinnedTrueAndPublishedAtIsNotNullAndDeletedAtIsNullOrderByPublishedAtDesc(any()))
                .thenReturn(List.of(publishedContent));
        when(contentRepository.findTop10ByStatusAndPublishedAtIsNotNullAndDeletedAtIsNullOrderByPublishedAtDesc(any()))
                .thenReturn(List.of(publishedContent));
        when(contentRepository.findTop10ByStatusAndPublishedAtIsNotNullAndDeletedAtIsNullOrderByLikeCountDescPublishedAtDesc(any()))
                .thenReturn(List.of(publishedContent));

        RecommendationResponse response = contentQueryService.recommendations();

        assertNotNull(response);
        assertEquals(1, response.pinned().size());
        assertEquals(1, response.latest().size());
        assertEquals(1, response.mostLiked().size());
    }

    @Test
    void list_returnsPaginatedResults() {
        Page<Content> page = new PageImpl<>(List.of(publishedContent));
        when(contentRepository.findAll(
                org.mockito.ArgumentMatchers
                        .<org.springframework.data.jpa.domain.Specification<Content>>any(),
                any(Pageable.class)
        ))
                .thenReturn(page);
        when(contentRepository.findAllWithSummaryRelationsByIdIn(anyList()))
                .thenReturn(List.of(publishedContent));

        PageResponse<ContentSummaryResponse> result = contentQueryService.list(
                "test", null, null, null, null, 0, 10
        );

        assertNotNull(result);
        assertEquals(1, result.items().size());
        assertEquals("Test Article", result.items().get(0).title());
        verify(contentRepository).findAllWithSummaryRelationsByIdIn(anyList());
        verify(mediaAssetRepository).findByContentIdInOrderByCreatedAtAsc(anyList());
    }

    @Test
    void detail_returnsContentWithLikeStatus() {
        when(contentRepository.findByIdAndStatusAndDeletedAtIsNull(
                eq(contentId),
                eq(ContentStatus.PUBLISHED)
        ))
                .thenReturn(Optional.of(publishedContent));
        when(interactionStateService.isLiked(eq(contentId), any(UUID.class)))
                .thenReturn(true);

        AuthenticatedUser user = new AuthenticatedUser(UUID.randomUUID(), "test@example.com", "Test", Role.USER);
        ContentDetailResponse detail = contentQueryService.detail(contentId, user);

        assertNotNull(detail);
        assertEquals("Test Article", detail.title());
        assertTrue(detail.likedByCurrentUser());
    }

    @Test
    void detail_returnsContentWithoutLikeForAnonymous() {
        when(contentRepository.findByIdAndStatusAndDeletedAtIsNull(
                eq(contentId),
                eq(ContentStatus.PUBLISHED)
        ))
                .thenReturn(Optional.of(publishedContent));

        ContentDetailResponse detail = contentQueryService.detail(contentId, null);

        assertNotNull(detail);
        assertFalse(detail.likedByCurrentUser());
    }

    @Test
    void detail_doesNotExposeLogicallyDeletedContentToAdmin() {
        AuthenticatedUser admin = new AuthenticatedUser(
                UUID.randomUUID(),
                "admin@example.com",
                "Admin",
                Role.ADMIN
        );
        when(contentRepository.findByIdAndDeletedAtIsNull(contentId))
                .thenReturn(Optional.empty());

        assertThrows(
                BusinessException.class,
                () -> contentQueryService.detail(contentId, admin)
        );
        verify(contentRepository, never()).findById(contentId);
    }
}
