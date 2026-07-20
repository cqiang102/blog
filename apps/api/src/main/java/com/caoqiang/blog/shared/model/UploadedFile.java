package com.caoqiang.blog.shared.model;

import java.io.IOException;
import java.io.InputStream;
import java.util.Objects;

/**
 * Framework-neutral description of an uploaded file.
 *
 * <p>The stream is opened lazily so validation and storage can each read it without retaining a
 * potentially large upload in heap memory.</p>
 */
public record UploadedFile(String originalFilename, String contentType, long size, InputStreamSource source) {

    public UploadedFile {
        if (size < 0) {
            throw new IllegalArgumentException("Uploaded file size must not be negative");
        }
        source = Objects.requireNonNull(source, "Uploaded file source must not be null");
    }

    public boolean isEmpty() {
        return size == 0;
    }

    public InputStream openStream() throws IOException {
        return source.openStream();
    }

    @FunctionalInterface
    public interface InputStreamSource {

        InputStream openStream() throws IOException;
    }
}
