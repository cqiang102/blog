package com.caoqiang.blog.content.application.api;

import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.repository.MediaAssetRepository;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class ContentOverviewService {

    private final ContentRepository contentRepository;
    private final MediaAssetRepository mediaAssetRepository;

    public ContentOverviewService(
            ContentRepository contentRepository,
            MediaAssetRepository mediaAssetRepository
    ) {
        this.contentRepository = contentRepository;
        this.mediaAssetRepository = mediaAssetRepository;
    }

    @Transactional(readOnly = true)
    public ContentOverview overview() {
        return new ContentOverview(contentRepository.count(), mediaAssetRepository.count());
    }
}
