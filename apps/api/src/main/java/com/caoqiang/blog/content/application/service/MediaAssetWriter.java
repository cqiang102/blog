package com.caoqiang.blog.content.application.service;

import com.caoqiang.blog.content.application.dto.AdminMediaResponse;
import com.caoqiang.blog.content.application.port.MediaStorage.StoredObject;
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import com.caoqiang.blog.content.domain.model.MediaReference;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.repository.MediaAssetRepository;
import com.caoqiang.blog.shared.exception.BusinessException;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** Persists uploaded-media metadata in a short transaction after storage I/O has completed. */
@Service
public class MediaAssetWriter {

    private final MediaAssetRepository mediaAssetRepository;
    private final ContentRepository contentRepository;

    public MediaAssetWriter(MediaAssetRepository mediaAssetRepository, ContentRepository contentRepository) {
        this.mediaAssetRepository = mediaAssetRepository;
        this.contentRepository = contentRepository;
    }

    @Transactional
    public AdminMediaResponse createUploaded(
            UUID contentId,
            MediaAssetType mediaType,
            StoredObject storedObject,
            String filename,
            String contentType,
            long byteSize) {
        Content content = contentId == null
                ? null
                : contentRepository
                        .findById(contentId)
                        .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
        MediaAsset mediaAsset = new MediaAsset(
                content,
                mediaType,
                storedObject.platform(),
                storedObject.objectKey(),
                null,
                filename,
                contentType,
                byteSize,
                null,
                null,
                null);
        mediaAsset.setPublicUrl(MediaReference.filePath(mediaAsset.getId()));
        return AdminMediaResponse.from(mediaAssetRepository.save(mediaAsset));
    }
}
