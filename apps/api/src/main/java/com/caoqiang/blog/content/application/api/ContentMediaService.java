package com.caoqiang.blog.content.application.api;

import com.caoqiang.blog.content.application.service.MediaAdminService;
import org.springframework.stereotype.Service;

/** Public content-module API for stable media URL and storage operations. */
@Service
public class ContentMediaService {

    private final MediaAdminService mediaAdminService;

    public ContentMediaService(MediaAdminService mediaAdminService) {
        this.mediaAdminService = mediaAdminService;
    }

    public String resolveUrl(String value) {
        return mediaAdminService.resolveUrl(value);
    }

    public String normalizeForPersistence(String value) {
        return mediaAdminService.normalizeStorageUrlForPersistence(value);
    }

    public void ensureUploadStorageReady() {
        mediaAdminService.ensureUploadStorageReady();
    }

    public String portableStoragePath(String value) {
        return mediaAdminService.portableStoragePath(value);
    }
}
