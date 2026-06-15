package com.caoqiang.blog.interaction;

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

import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.shared.domain.event.DomainEventPublisher;
import com.caoqiang.blog.user.domain.model.User;
import java.time.Instant;
import java.util.Optional;
import java.util.Set;
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
    private ContentRepository contentRepository;

    @Mock
    private DomainEventPublisher domainEventPublisher;

    @Test
    void deletingLikeDecrementsContentLikeCount() {
        Content content = content();
        Like like = new Like(content, user());
        InteractionAdminService service = new InteractionAdminService(
                likeRepository,
                viewRecordRepository,
                contentRepository,
                domainEventPublisher
        );
        when(likeRepository.findById(like.getId())).thenReturn(Optional.of(like));

        service.deleteLike(like.getId());

        verify(likeRepository).delete(like);
        verify(contentRepository).incrementLikeCount(content.getId(), -1);
        verify(domainEventPublisher).publishEvent(any());
    }

    @Test
    void deletingViewDecrementsContentViewCount() {
        Content content = content();
        ViewRecord viewRecord = new ViewRecord(content, user(), "anonymous", "iphash", "JUnit");
        InteractionAdminService service = new InteractionAdminService(
                likeRepository,
                viewRecordRepository,
                contentRepository,
                domainEventPublisher
        );
        when(viewRecordRepository.findById(viewRecord.getId())).thenReturn(Optional.of(viewRecord));

        service.deleteView(viewRecord.getId());

        verify(viewRecordRepository).delete(viewRecord);
        verify(contentRepository).incrementViewCount(content.getId(), -1);
    }

    private Content content() {
        return new Content(
                "互动测试内容",
                "interaction-admin-test",
                ContentType.ARTICLE,
                ContentStatus.PUBLISHED,
                "摘要",
                "正文",
                false,
                Instant.parse("2026-06-01T00:00:00Z"),
                Set.of()
        );
    }

    private User user() {
        return User.register("reader@example.com", "hash", "读者");
    }
}
