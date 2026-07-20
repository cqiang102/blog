package com.caoqiang.blog.content.application.api;

/** Public content-module snapshot for a newly stored media object. */
public record ContentMediaUpload(String platform, String objectKey) {

    public ContentMediaUpload {
        if (platform == null || platform.isBlank()) {
            throw new IllegalArgumentException("Storage platform must not be blank");
        }
        if (objectKey == null || objectKey.isBlank()) {
            throw new IllegalArgumentException("Storage object key must not be blank");
        }
    }
}
