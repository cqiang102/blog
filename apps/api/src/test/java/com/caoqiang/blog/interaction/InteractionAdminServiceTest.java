package com.caoqiang.blog.interaction;

import com.caoqiang.blog.content.application.api.ContentInteractionService;
import com.caoqiang.blog.interaction.application.service.InteractionReferenceData;
import com.caoqiang.blog.interaction.application.dto.AdminLikeResponse;
import com.caoqiang.blog.interaction.application.dto.AdminViewRecordResponse;
import com.caoqiang.blog.interaction.domain.model.Like;
import com.caoqiang.blog.interaction.domain.model.ViewRecord;
import com.caoqiang.blog.interaction.domain.repository.LikeRepository;
import com.caoqiang.blog.interaction.domain.repository.ViewRecordRepository;
import com.caoqiang.blog.interaction.application.service.InteractionAdminService;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.shared.domain.event.DomainEventPublisher;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class InteractionAdminServiceTest {

    @Mock
    private LikeRepository likeRepository;

    @Mock
    private ViewRecordRepository viewRecordRepository;

    @Mock
    private ContentInteractionService contentInteractionService;

    @Mock
    private DomainEventPublisher domainEventPublisher;

    @Mock
    private InteractionReferenceData referenceData;

    @Test
    void deletingLikeDecrementsContentLikeCount() {
        UUID contentId = UUID.randomUUID();
        Like like = new Like(contentId, UUID.randomUUID());
        InteractionAdminService service = new InteractionAdminService(
                likeRepository,
                viewRecordRepository,
                contentInteractionService,
                domainEventPublisher,
                referenceData
        );
        when(likeRepository.findById(like.getId())).thenReturn(Optional.of(like));

        service.deleteLike(like.getId());

        verify(likeRepository).delete(like);
        verify(contentInteractionService).incrementLikeCount(contentId, -1);
        verify(domainEventPublisher).publishEvent(any());
    }

    @Test
    void deletingViewDecrementsContentViewCount() {
        UUID contentId = UUID.randomUUID();
        ViewRecord viewRecord = new ViewRecord(contentId, UUID.randomUUID(), "anonymous", "iphash", "JUnit");
        InteractionAdminService service = new InteractionAdminService(
                likeRepository,
                viewRecordRepository,
                contentInteractionService,
                domainEventPublisher,
                referenceData
        );
        when(viewRecordRepository.findById(viewRecord.getId())).thenReturn(Optional.of(viewRecord));

        service.deleteView(viewRecord.getId());

        verify(viewRecordRepository).delete(viewRecord);
        verify(contentInteractionService).incrementViewCount(contentId, -1);
    }
}
