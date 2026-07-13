package com.caoqiang.blog.interaction;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.interaction.application.api.InteractionStateService;
import com.caoqiang.blog.interaction.domain.repository.LikeRepository;
import java.util.UUID;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class InteractionStateServiceTest {

    @Mock
    private LikeRepository likeRepository;

    @Test
    void exposesLikeStateWithoutLeakingTheRepository() {
        UUID contentId = UUID.randomUUID();
        UUID userId = UUID.randomUUID();
        when(likeRepository.existsByContentIdAndUserId(contentId, userId)).thenReturn(true);
        InteractionStateService service = new InteractionStateService(likeRepository);

        assertThat(service.isLiked(contentId, userId)).isTrue();
        verify(likeRepository).existsByContentIdAndUserId(contentId, userId);
    }
}
