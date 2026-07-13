package com.caoqiang.blog.content;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verify;

import com.caoqiang.blog.content.application.dto.AdminContentRequest;
import com.caoqiang.blog.content.application.service.ContentAdminService;
import com.caoqiang.blog.content.application.service.MediaAdminService;
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
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ContentAdminServiceTest {

    @Mock
    private ContentRepository contentRepository;
    @Mock
    private TagRepository tagRepository;
    @Mock
    private MediaAssetRepository mediaAssetRepository;
    @Mock
    private DomainEventPublisher domainEventPublisher;
    @Mock
    private MediaAdminService mediaAdminService;

    @Test
    void updateUsesExistingVideoTypeForNewExternalMediaWhenTypeIsOmitted() {
        Content content = new Content(
                "视频",
                "video",
                ContentType.VIDEO,
                ContentStatus.DRAFT,
                null,
                null,
                false,
                null,
                Set.of()
        );
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
                List.of(
                        "https://cdn.example.com/video.mp4",
                        "https://cdn.example.com/video.mp4"
                ),
                null
        );
        ContentAdminService service = new ContentAdminService(
                contentRepository,
                tagRepository,
                mediaAssetRepository,
                domainEventPublisher,
                mediaAdminService
        );

        when(contentRepository.findById(content.getId())).thenReturn(Optional.of(content));
        when(contentRepository.existsBySlugAndIdNot("video", content.getId())).thenReturn(false);
        when(mediaAssetRepository.save(any(MediaAsset.class)))
                .thenAnswer(invocation -> invocation.getArgument(0));

        service.update(content.getId(), request);

        assertThat(content.getMediaAssets()).singleElement()
                .extracting(MediaAsset::getType)
                .isEqualTo(MediaAssetType.VIDEO);
        verify(domainEventPublisher).publishEvent(any(ContentArchivedEvent.class));
    }
}
