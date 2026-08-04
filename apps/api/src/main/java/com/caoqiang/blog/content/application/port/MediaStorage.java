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

    /**
     * 上传到指定可见性平台。默认实现等同公开上传；基础设施适配器按需覆盖。
     *
     * @param isPrivate true 时存入私有空间（lacia-private），false 时存入公开空间
     */
    default StoredObject upload(
            UploadedFile file, String path, String filename, String contentType, boolean isPrivate) {
        return upload(file, path, filename, contentType);
    }

    void delete(StoredObject object);

    /**
     * 返回对象的公开直链（仅公开平台有）；私有对象返回 {@link Optional#empty()}，
     * 调用方应回退到 {@link #presignedUrl(StoredObject, Instant)}。
     */
    Optional<String> publicUrl(StoredObject object);

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
