package com.caoqiang.blog.content.infrastructure.storage;

import com.caoqiang.blog.content.application.port.MediaStorage;
import com.caoqiang.blog.content.application.port.MediaStorageProvisioner;
import com.caoqiang.blog.shared.model.UploadedFile;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.URI;
import java.time.Instant;
import java.util.Date;
import java.util.Optional;
import org.dromara.x.file.storage.core.FileInfo;
import org.dromara.x.file.storage.core.FileStorageService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

/** x-file-storage adapter for the media storage application port. */
@Component
public class XFileMediaStorageAdapter implements MediaStorage {

    private static final Logger log = LoggerFactory.getLogger(XFileMediaStorageAdapter.class);

    private final FileStorageService fileStorageService;
    private final MediaStorageProvisioner storageProvisioner;
    private final String storageEndpoint;
    private final String publicEndpoint;
    private final String bucketName;
    private final String basePath;

    public XFileMediaStorageAdapter(
            FileStorageService fileStorageService,
            MediaStorageProvisioner storageProvisioner,
            @Value("${dromara.x-file-storage.minio[0].end-point:http://localhost:9000}") String storageEndpoint,
            @Value("${MINIO_PUBLIC_ENDPOINT:}") String publicEndpoint,
            @Value("${dromara.x-file-storage.minio[0].bucket-name:blog-media}") String bucketName,
            @Value("${dromara.x-file-storage.minio[0].base-path:uploads/}") String basePath) {
        this.fileStorageService = fileStorageService;
        this.storageProvisioner = storageProvisioner;
        this.storageEndpoint = storageEndpoint;
        this.publicEndpoint = publicEndpoint;
        this.bucketName = bucketName;
        this.basePath = normalizeDirectory(basePath);
    }

    @Override
    public void ensureReady() {
        storageProvisioner.ensureReady();
    }

    @Override
    public StoredObject upload(UploadedFile file, String path, String filename, String contentType) {
        ensureReady();
        FileInfo fileInfo;
        try (var input = file.openStream()) {
            fileInfo = fileStorageService
                    .of(input, file.originalFilename(), contentType, file.size())
                    .setPath(path)
                    .setSaveFilename(filename)
                    .setContentType(contentType)
                    .upload();
        } catch (IOException exception) {
            throw new UncheckedIOException("Unable to read uploaded media", exception);
        }
        String storedBasePath = StringUtils.hasText(fileInfo.getBasePath()) ? fileInfo.getBasePath() : basePath;
        String objectKey = joinKey(storedBasePath, fileInfo.getPath(), fileInfo.getFilename());
        return new StoredObject(fileInfo.getPlatform(), objectKey);
    }

    @Override
    public void delete(StoredObject object) {
        if (!fileStorageService.delete(fileInfo(object))) {
            throw new IllegalStateException("Object storage did not delete " + object.objectKey());
        }
    }

    @Override
    public String presignedUrl(StoredObject object, Instant expiresAt) {
        String fallbackUrl = portablePath(object.objectKey());
        return generatePresignedUrl(fileInfo(object), expiresAt, fallbackUrl);
    }

    @Override
    public Optional<String> presignedUrl(String sourceUrl, Instant expiresAt) {
        Optional<String> objectKey = objectKeyFromStorageUrl(sourceUrl);
        if (objectKey.isEmpty()) {
            return Optional.empty();
        }
        StoredObject object =
                new StoredObject(fileStorageService.getProperties().getDefaultPlatform(), objectKey.get());
        return Optional.of(generatePresignedUrl(fileInfo(object), expiresAt, portablePath(objectKey.get())));
    }

    @Override
    public String normalizeForPersistence(String sourceUrl) {
        if (!StringUtils.hasText(sourceUrl)) {
            return null;
        }
        String trimmed = sourceUrl.trim();
        return objectKeyFromStorageUrl(trimmed).map(this::portablePath).orElse(trimmed);
    }

    @Override
    public String portablePath(String objectKey) {
        String publicBase = publicStorageBasePath();
        return publicBase + "/" + bucketName + "/" + fullObjectKey(objectKey);
    }

    private String generatePresignedUrl(FileInfo fileInfo, Instant expiresAt, String fallbackUrl) {
        String signedUrl = fileStorageService.generatePresignedUrl(fileInfo, Date.from(expiresAt));
        if (!StringUtils.hasText(signedUrl)) {
            log.warn(
                    "Object storage returned no presigned URL: platform={}, path={}, filename={}",
                    fileInfo.getPlatform(),
                    fileInfo.getPath(),
                    fileInfo.getFilename());
            return fallbackUrl;
        }
        return publicPresignedUrl(signedUrl);
    }

    private FileInfo fileInfo(StoredObject object) {
        String fullKey = fullObjectKey(object.objectKey());
        String relativeKey = stripBasePath(fullKey);
        int lastSlash = relativeKey.lastIndexOf('/');
        String path = lastSlash < 0 ? "" : relativeKey.substring(0, lastSlash + 1);
        String filename = lastSlash < 0 ? relativeKey : relativeKey.substring(lastSlash + 1);

        FileInfo fileInfo = new FileInfo();
        fileInfo.setPlatform(object.platform());
        fileInfo.setBasePath(basePath);
        fileInfo.setPath(path);
        fileInfo.setFilename(filename);
        fileInfo.setUrl(buildStorageUrl(fullKey));
        return fileInfo;
    }

    private String publicPresignedUrl(String signedUrl) {
        if (!StringUtils.hasText(publicEndpoint)) {
            return signedUrl;
        }
        try {
            URI signedUri = URI.create(signedUrl);
            URI endpointUri = URI.create(storageEndpoint);
            if (!equalsIgnoreCase(signedUri.getHost(), endpointUri.getHost())
                    || effectivePort(signedUri) != effectivePort(endpointUri)) {
                return signedUrl;
            }

            String publicBase = publicEndpoint.replaceAll("/+$", "");
            String query = signedUri.getRawQuery();
            return publicBase + signedUri.getRawPath() + (query == null ? "" : "?" + query);
        } catch (IllegalArgumentException exception) {
            log.warn("Unable to rewrite object storage presigned URL", exception);
            return signedUrl;
        }
    }

    private Optional<String> objectKeyFromStorageUrl(String sourceUrl) {
        try {
            URI uri = URI.create(sourceUrl);
            String path = uri.getPath();
            if (!StringUtils.hasText(path)) {
                return Optional.empty();
            }
            String normalizedPath = path.replaceAll("^/+", "");
            if (!isConfiguredStorageUrl(uri, normalizedPath)) {
                return Optional.empty();
            }
            String bucketPrefix = bucketName + "/";
            int bucketIndex = normalizedPath.indexOf(bucketPrefix);
            if (bucketIndex < 0) {
                return Optional.empty();
            }
            String objectKey = normalizedPath.substring(bucketIndex + bucketPrefix.length());
            return StringUtils.hasText(objectKey) ? Optional.of(objectKey) : Optional.empty();
        } catch (IllegalArgumentException ignored) {
            return Optional.empty();
        }
    }

    private boolean isConfiguredStorageUrl(URI uri, String normalizedPath) {
        try {
            URI endpointUri = URI.create(storageEndpoint);
            if (equalsIgnoreCase(uri.getHost(), endpointUri.getHost())
                    && effectivePort(uri) == effectivePort(endpointUri)) {
                return true;
            }
        } catch (IllegalArgumentException ignored) {
            // Continue with stable/public path checks.
        }

        String storageBase = publicStorageBasePath().replaceAll("^/+", "").replaceAll("/+$", "");
        if (StringUtils.hasText(storageBase)
                && (normalizedPath.equals(storageBase) || normalizedPath.startsWith(storageBase + "/"))) {
            return true;
        }
        if (!StringUtils.hasText(publicEndpoint)) {
            return false;
        }

        try {
            URI publicUri = URI.create(publicEndpoint);
            String publicPath = publicUri.getPath().replaceAll("^/+", "").replaceAll("/+$", "");
            boolean pathMatches = publicPath.isEmpty()
                    || normalizedPath.equals(publicPath)
                    || normalizedPath.startsWith(publicPath + "/");
            if (!pathMatches) {
                return false;
            }
            return uri.getHost() == null
                    || (equalsIgnoreCase(uri.getHost(), publicUri.getHost())
                            && effectivePort(uri) == effectivePort(publicUri));
        } catch (IllegalArgumentException ignored) {
            return false;
        }
    }

    private String publicStorageBasePath() {
        if (!StringUtils.hasText(publicEndpoint)) {
            return "/minio";
        }
        try {
            String path = URI.create(publicEndpoint).getPath();
            if (!StringUtils.hasText(path) || "/".equals(path)) {
                return "";
            }
            return "/" + path.replaceAll("^/+", "").replaceAll("/+$", "");
        } catch (IllegalArgumentException ignored) {
            return "/minio";
        }
    }

    private String fullObjectKey(String objectKey) {
        String normalized = objectKey.replaceAll("^/+", "");
        if (basePath.isEmpty() || normalized.startsWith(basePath)) {
            return normalized;
        }
        return basePath + normalized;
    }

    private String stripBasePath(String objectKey) {
        return !basePath.isEmpty() && objectKey.startsWith(basePath)
                ? objectKey.substring(basePath.length())
                : objectKey;
    }

    private String buildStorageUrl(String objectKey) {
        return storageEndpoint.replaceAll("/+$", "") + "/" + bucketName + "/" + objectKey;
    }

    private static String normalizeDirectory(String value) {
        if (!StringUtils.hasText(value)) {
            return "";
        }
        String normalized = value.replaceAll("^/+", "").replaceAll("/+$", "");
        return normalized.isEmpty() ? "" : normalized + "/";
    }

    private static String joinKey(String... segments) {
        StringBuilder result = new StringBuilder();
        for (String segment : segments) {
            if (!StringUtils.hasText(segment)) {
                continue;
            }
            String normalized = segment.replaceAll("^/+", "").replaceAll("/+$", "");
            if (normalized.isEmpty()) {
                continue;
            }
            if (!result.isEmpty()) {
                result.append('/');
            }
            result.append(normalized);
        }
        return result.toString();
    }

    private static boolean equalsIgnoreCase(String first, String second) {
        return first != null && second != null && first.equalsIgnoreCase(second);
    }

    private static int effectivePort(URI uri) {
        if (uri.getPort() > 0) {
            return uri.getPort();
        }
        return "https".equalsIgnoreCase(uri.getScheme()) ? 443 : 80;
    }
}
