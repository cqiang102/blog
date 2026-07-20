package com.caoqiang.blog.shared.infrastructure.web;

import com.caoqiang.blog.shared.model.UploadedFile;
import org.springframework.web.multipart.MultipartFile;

/** Maps Spring MVC multipart input at the HTTP boundary into an application-level upload. */
public final class MultipartFileUploads {

    private MultipartFileUploads() {}

    public static UploadedFile from(MultipartFile file) {
        if (file == null) {
            return null;
        }
        return new UploadedFile(
                file.getOriginalFilename(), file.getContentType(), file.getSize(), file::getInputStream);
    }
}
