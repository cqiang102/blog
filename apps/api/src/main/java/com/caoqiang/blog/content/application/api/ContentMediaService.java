package com.caoqiang.blog.content.application.api;

import com.caoqiang.blog.content.application.port.MediaStorage;
import com.caoqiang.blog.content.application.port.MediaStorage.StoredObject;
import com.caoqiang.blog.content.application.service.MediaAdminService;
import com.caoqiang.blog.shared.model.UploadedFile;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/** Public content-module API for stable media URL and storage operations. */
@Service
public class ContentMediaService {

    private final MediaAdminService mediaAdminService;
    private final MediaStorage mediaStorage;

    public ContentMediaService(MediaAdminService mediaAdminService, MediaStorage mediaStorage) {
        this.mediaAdminService = mediaAdminService;
        this.mediaStorage = mediaStorage;
    }

    public String resolveUrl(String value) {
        return mediaAdminService.resolveUrl(value);
    }

    public String normalizeForPersistence(String value) {
        return mediaStorage.normalizeForPersistence(value);
    }

    public String portableStoragePath(String value) {
        return mediaStorage.portablePath(value);
    }

    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    public ContentMediaUpload upload(UploadedFile file, String path, String filename, String contentType) {
        StoredObject storedObject = mediaStorage.upload(file, path, filename, contentType);
        return new ContentMediaUpload(storedObject.platform(), storedObject.objectKey());
    }

    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    public void delete(ContentMediaUpload upload) {
        mediaStorage.delete(new StoredObject(upload.platform(), upload.objectKey()));
    }
}
