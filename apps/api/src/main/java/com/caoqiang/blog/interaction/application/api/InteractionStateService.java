package com.caoqiang.blog.interaction.application.api;

import com.caoqiang.blog.interaction.domain.repository.LikeRepository;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Public interaction-module API for content-facing interaction state. */
@Service
public class InteractionStateService {

    private final LikeRepository likeRepository;

    public InteractionStateService(LikeRepository likeRepository) {
        this.likeRepository = likeRepository;
    }

    @Transactional(readOnly = true)
    public boolean isLiked(UUID contentId, UUID userId) {
        return likeRepository.existsByContentIdAndUserId(contentId, userId);
    }
}
