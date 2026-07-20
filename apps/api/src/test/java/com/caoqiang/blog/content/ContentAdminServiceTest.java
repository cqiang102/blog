package com.caoqiang.blog.content;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.content.application.dto.AdminContentRequest;
import com.caoqiang.blog.content.application.service.ContentAdminService;
import com.caoqiang.blog.content.application.service.ContentMediaSynchronizer;
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.repository.MediaAssetRepository;
import com.caoqiang.blog.content.domain.repository.TagRepository;
import com.caoqiang.blog.content.event.ContentArchivedEvent;
import com.caoqiang.blog.shared.domain.event.DomainEventPublisher;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.Pageable;

@ExtendWith(MockitoExtension.class)
class ContentAdminServiceTest {

    private static final Clock FIXED_CLOCK = Clock.fixed(Instant.parse("2026-06-26T08:00:00Z"), ZoneOffset.UTC);

    @Mock
    private ContentRepository contentRepository;

    @Mock
    private TagRepository tagRepository;

    @Mock
    private MediaAssetRepository mediaAssetRepository;

    @Mock
    private DomainEventPublisher domainEventPublisher;

    @Test
    void updateUsesExistingVideoTypeForNewExternalMediaWhenTypeIsOmitted() {
        Content content =
                new Content("视频", "video", ContentType.VIDEO, ContentStatus.DRAFT, null, null, false, null, Set.of());
        AdminContentRequest request = new AdminContentRequest(
                "视频",
                "video",
                null,
                ContentStatus.DRAFT,
                null,
                null,
                false,
                null,
                List.of(),
                List.of("https://cdn.example.com/video.mp4", "https://cdn.example.com/video.mp4"),
                null);
        ContentAdminService service = new ContentAdminService(
                contentRepository,
                tagRepository,
                new ContentMediaSynchronizer(mediaAssetRepository),
                Clock.systemUTC(),
                domainEventPublisher);

        when(contentRepository.findById(content.getId())).thenReturn(Optional.of(content));
        when(contentRepository.existsBySlugAndIdNot("video", content.getId())).thenReturn(false);
        when(mediaAssetRepository.save(any(MediaAsset.class))).thenAnswer(invocation -> invocation.getArgument(0));

        service.update(content.getId(), request);

        assertThat(content.getMediaAssets())
                .singleElement()
                .extracting(MediaAsset::getType)
                .isEqualTo(MediaAssetType.VIDEO);
        verify(domainEventPublisher).publishEvent(any(ContentArchivedEvent.class));
    }

    @Test
    void updateKeepsOriginalPublishTimeWhenPublishedStatusAndTimeAreOmitted() {
        Instant originalPublishedAt = Instant.parse("2025-01-02T03:04:05Z");
        Content content = new Content(
                "文章",
                "article",
                ContentType.ARTICLE,
                ContentStatus.PUBLISHED,
                null,
                "正文",
                false,
                originalPublishedAt,
                Set.of());
        AdminContentRequest request = new AdminContentRequest(
                "更新后的文章", "article", null, null, null, "更新后的正文", false, null, List.of(), null, null);

        when(contentRepository.findById(content.getId())).thenReturn(Optional.of(content));
        when(contentRepository.existsBySlugAndIdNot("article", content.getId())).thenReturn(false);

        contentAdminService(FIXED_CLOCK).update(content.getId(), request);

        assertThat(content.getPublishedAt()).isEqualTo(originalPublishedAt);
    }

    @Test
    void updateUsesClockOnlyWhenContentIsPublishedForTheFirstTime() {
        Content content =
                new Content("草稿", "draft", ContentType.ARTICLE, ContentStatus.DRAFT, null, null, false, null, Set.of());
        AdminContentRequest request = new AdminContentRequest(
                "草稿", "draft", null, ContentStatus.PUBLISHED, null, null, false, null, List.of(), null, null);

        when(contentRepository.findById(content.getId())).thenReturn(Optional.of(content));
        when(contentRepository.existsBySlugAndIdNot("draft", content.getId())).thenReturn(false);

        contentAdminService(FIXED_CLOCK).update(content.getId(), request);

        assertThat(content.getPublishedAt()).isEqualTo(FIXED_CLOCK.instant());
    }

    @Test
    void domainRejectsPublishedContentWithoutAnExplicitPublishTime() {
        assertThatThrownBy(() -> new Content(
                        "文章",
                        "article",
                        ContentType.ARTICLE,
                        ContentStatus.PUBLISHED,
                        null,
                        null,
                        false,
                        null,
                        Set.of()))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("publishedAt");
    }

    @Test
    void optionsUsesTheLightweightProjectionAndSearchesByTrimmedTitle() {
        UUID contentId = UUID.randomUUID();
        ContentRepository.ContentOptionProjection projection = mock(ContentRepository.ContentOptionProjection.class);
        when(projection.getId()).thenReturn(contentId);
        when(projection.getTitle()).thenReturn("Java 生态");
        when(contentRepository.findContentOptionsByDeletedAtIsNullAndTitleContainingIgnoreCase(
                        eq("Java"), any(Pageable.class)))
                .thenAnswer(invocation -> new PageImpl<>(List.of(projection), invocation.getArgument(1), 1));

        var result = contentAdminService(FIXED_CLOCK).options("  Java  ", 0, 20);

        assertThat(result.items()).singleElement().satisfies(option -> {
            assertThat(option.id()).isEqualTo(contentId);
            assertThat(option.title()).isEqualTo("Java 生态");
        });
        assertThat(result.page()).isZero();
        assertThat(result.size()).isEqualTo(20);
        verify(contentRepository)
                .findContentOptionsByDeletedAtIsNullAndTitleContainingIgnoreCase(eq("Java"), any(Pageable.class));
    }

    private ContentAdminService contentAdminService(Clock clock) {
        return new ContentAdminService(
                contentRepository,
                tagRepository,
                new ContentMediaSynchronizer(mediaAssetRepository),
                clock,
                domainEventPublisher);
    }
}
