package com.caoqiang.blog.content.infrastructure.storage;

import com.caoqiang.blog.content.application.port.MediaStorage;
import com.caoqiang.blog.content.application.port.MediaStorageProvisioner;
import com.caoqiang.blog.shared.model.UploadedFile;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.net.URI;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
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

/**
 * x-file-storage 适配器（七牛云 Kodo 私有空间）。
 *
 * <p>所有上传写入 {@code qiniu-private}（lacia-private），访问必须通过预签名 URL
 * （file.lacia.cn + 下载凭证）。lacia-public 仅用于 Flutter 静态资源的 CDN 加速，
 * 与后端上传无关。</p>
 */
@Component
public class XFileMediaStorageAdapter implements MediaStorage {

    private static final Logger log = LoggerFactory.getLogger(XFileMediaStorageAdapter.class);

    private static final String LEGACY_MINIO_PREFIX = "minio/";
    private static final String STORAGE_FILE_PATH = "/api/v1/storage/file";

    private final FileStorageService fileStorageService;
    private final MediaStorageProvisioner storageProvisioner;
    private final String privatePlatform;
    private final String privateDomain;
    private final String privateBucket;
    private final String basePath;

    public XFileMediaStorageAdapter(
            FileStorageService fileStorageService,
            MediaStorageProvisioner storageProvisioner,
            @Value("${dromara.x-file-storage.default-platform:qiniu-private}") String privatePlatform,
            @Value("${dromara.x-file-storage.qiniu-kodo[0].domain:https://file.lacia.cn/}") String privateDomain,
            @Value("${dromara.x-file-storage.qiniu-kodo[0].bucket-name:lacia-private}") String privateBucket,
            @Value("${dromara.x-file-storage.qiniu-kodo[0].base-path:uploads/}") String basePath) {
        this.fileStorageService = fileStorageService;
        this.storageProvisioner = storageProvisioner;
        this.privatePlatform = privatePlatform;
        this.privateDomain = normalizeDirectory(privateDomain);
        this.privateBucket = privateBucket;
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
        return generatePresignedUrl(fileInfo(object), expiresAt, portablePath(object.objectKey()));
    }

    @Override
    public String presignedUrlByKey(String objectKey, Instant expiresAt) {
        StoredObject object = new StoredObject(privatePlatform, objectKey);
        return generatePresignedUrl(fileInfo(object), expiresAt, portablePath(objectKey));
    }

    @Override
    public Optional<String> presignedUrl(String sourceUrl, Instant expiresAt) {
        Optional<String> objectKey = objectKeyFromStorageUrl(sourceUrl);
        if (objectKey.isEmpty()) {
            return Optional.empty();
        }
        StoredObject object = new StoredObject(privatePlatform, objectKey.get());
        return Optional.of(generatePresignedUrl(fileInfo(object), expiresAt, sourceUrl));
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
        String fullKey = fullObjectKey(objectKey);
        return STORAGE_FILE_PATH + "?key="
                + URLEncoder.encode(fullKey, StandardCharsets.UTF_8);
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
        return signedUrl;
    }

    private FileInfo fileInfo(StoredObject object) {
        String resolvedPlatform = resolvePlatform(object.platform());
        if (!resolvedPlatform.equals(object.platform())) {
            log.warn(
                    "Media object uses legacy/unknown platform {}, resolving to {}: key={}",
                    object.platform(),
                    resolvedPlatform,
                    object.objectKey());
        }
        String fullKey = fullObjectKey(object.objectKey());
        String relativeKey = stripBasePath(fullKey);
        int lastSlash = relativeKey.lastIndexOf('/');
        String path = lastSlash < 0 ? "" : relativeKey.substring(0, lastSlash + 1);
        String filename = lastSlash < 0 ? relativeKey : relativeKey.substring(lastSlash + 1);

        FileInfo fileInfo = new FileInfo();
        fileInfo.setPlatform(resolvedPlatform);
        fileInfo.setBasePath(basePath);
        fileInfo.setPath(path);
        fileInfo.setFilename(filename);
        return fileInfo;
    }

    private Optional<String> objectKeyFromStorageUrl(String sourceUrl) {
        try {
            URI uri = URI.create(sourceUrl);
            String path = uri.getPath();
            if (!StringUtils.hasText(path)) {
                return Optional.empty();
            }
            String normalizedPath = path.replaceAll("^/+", "");

            // 1) 私有 CDN 域名（file.lacia.cn）：key 就是路径
            if (hostMatches(sourceUrl, privateDomain)) {
                return StringUtils.hasText(normalizedPath)
                        ? Optional.of(normalizedPath)
                        : Optional.empty();
            }

            // 2) 兼容旧 MinIO 代理路径 /minio/{bucket}/{key}
            if (normalizedPath.startsWith(LEGACY_MINIO_PREFIX)) {
                String rest = normalizedPath.substring(LEGACY_MINIO_PREFIX.length());
                String objectKey = stripBucketPrefix(rest);
                return StringUtils.hasText(objectKey) ? Optional.of(objectKey) : Optional.empty();
            }

            // 3) 稳定存储代理路径 /api/v1/storage/file?key=...
            if (normalizedPath.equals(STORAGE_FILE_PATH.replaceAll("^/+", ""))) {
                String key = uri.getQuery() == null ? null : queryValue(uri.getQuery(), "key");
                return StringUtils.hasText(key) ? Optional.of(key) : Optional.empty();
            }
            return Optional.empty();
        } catch (IllegalArgumentException ignored) {
            return Optional.empty();
        }
    }

    private String queryValue(String query, String name) {
        for (String pair : query.split("&")) {
            int eq = pair.indexOf('=');
            if (eq > 0 && pair.substring(0, eq).equals(name)) {
                return java.net.URLDecoder.decode(pair.substring(eq + 1), StandardCharsets.UTF_8);
            }
        }
        return null;
    }

    private String stripBucketPrefix(String path) {
        String prefix = privateBucket + "/";
        if (path.startsWith(prefix)) {
            return path.substring(prefix.length());
        }
        return null;
    }

    /**
     * 兼容迁移前的历史平台标识（如 minio-1）：一律映射到当前私有平台，
     * 避免旧数据库记录导致预签名/删除直接报“平台不存在”。
     */
    private String resolvePlatform(String platform) {
        if (platform == null || platform.isBlank() || !platform.equals(privatePlatform)) {
            return privatePlatform;
        }
        return platform;
    }

    private boolean hostMatches(String url, String domain) {
        if (!StringUtils.hasText(url) || !StringUtils.hasText(domain)) {
            return false;
        }
        try {
            String urlHost = URI.create(url).getHost();
            String domainHost = URI.create(domain).getHost();
            return urlHost != null && equalsIgnoreCase(urlHost, domainHost);
        } catch (IllegalArgumentException ignored) {
            return false;
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
}
