package com.caoqiang.blog.content.application.port;

import com.caoqiang.blog.shared.model.UploadedFile;
import java.time.Instant;
import java.util.Optional;

/**
 * Application boundary for managed object storage.
 *
 * <p>The application layer deals only with stable storage identifiers. Vendor-specific objects,
 * endpoint rewriting and bucket configuration belong to the infrastructure adapter.
 */
public interface MediaStorage {

    void ensureReady();

    StoredObject upload(UploadedFile file, String path, String filename, String contentType);

    void delete(StoredObject object);

    String presignedUrl(StoredObject object, Instant expiresAt);

    Optional<String> presignedUrl(String sourceUrl, Instant expiresAt);

    String normalizeForPersistence(String sourceUrl);

    String portablePath(String objectKey);

    /** Stable reference to an object stored by a configured platform. */
    record StoredObject(String platform, String objectKey) {

        public StoredObject {
            if (platform == null || platform.isBlank()) {
                throw new IllegalArgumentException("Storage platform must not be blank");
            }
            if (objectKey == null || objectKey.isBlank()) {
                throw new IllegalArgumentException("Storage object key must not be blank");
            }
        }
    }
}
