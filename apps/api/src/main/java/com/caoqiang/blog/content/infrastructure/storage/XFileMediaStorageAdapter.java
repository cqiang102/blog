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

/**
 * x-file-storage 适配器（七牛云 Kodo）。
 *
 * <p>配置两个平台：
 * <ul>
 *   <li>{@code qiniu-public}（默认）：lacia-public 公开空间，CDN 域名 static.blog.lacia.cn</li>
 *   <li>{@code qiniu-private}：lacia-private 私有空间，CDN 域名 file.lacia.cn（签名访问）</li>
 * </ul>
 */
@Component
public class XFileMediaStorageAdapter implements MediaStorage {

    private static final Logger log = LoggerFactory.getLogger(XFileMediaStorageAdapter.class);

    private static final String LEGACY_MINIO_PREFIX = "minio/";

    private final FileStorageService fileStorageService;
    private final MediaStorageProvisioner storageProvisioner;
    private final String publicPlatform;
    private final String privatePlatform;
    private final String publicDomain;
    private final String privateDomain;
    private final String publicBucket;
    private final String privateBucket;
    private final String basePath;

    public XFileMediaStorageAdapter(
            FileStorageService fileStorageService,
            MediaStorageProvisioner storageProvisioner,
            @Value("${dromara.x-file-storage.default-platform:qiniu-public}") String publicPlatform,
            @Value("${dromara.x-file-storage.qiniu-kodo[1].platform:qiniu-private}") String privatePlatform,
            @Value("${dromara.x-file-storage.qiniu-kodo[0].domain:https://static.blog.lacia.cn/}") String publicDomain,
            @Value("${dromara.x-file-storage.qiniu-kodo[1].domain:https://file.lacia.cn/}") String privateDomain,
            @Value("${dromara.x-file-storage.qiniu-kodo[0].bucket-name:lacia-public}") String publicBucket,
            @Value("${dromara.x-file-storage.qiniu-kodo[1].bucket-name:lacia-private}") String privateBucket,
            @Value("${dromara.x-file-storage.qiniu-kodo[0].base-path:uploads/}") String basePath) {
        this.fileStorageService = fileStorageService;
        this.storageProvisioner = storageProvisioner;
        this.publicPlatform = publicPlatform;
        this.privatePlatform = privatePlatform;
        this.publicDomain = normalizeDirectory(publicDomain);
        this.privateDomain = normalizeDirectory(privateDomain);
        this.publicBucket = publicBucket;
        this.privateBucket = privateBucket;
        this.basePath = normalizeDirectory(basePath);
    }

    @Override
    public void ensureReady() {
        storageProvisioner.ensureReady();
    }

    @Override
    public StoredObject upload(UploadedFile file, String path, String filename, String contentType) {
        return upload(file, path, filename, contentType, false);
    }

    @Override
    public StoredObject upload(
            UploadedFile file, String path, String filename, String contentType, boolean isPrivate) {
        ensureReady();
        FileInfo fileInfo;
        try (var input = file.openStream()) {
            var pretreatment = fileStorageService
                    .of(input, file.originalFilename(), contentType, file.size())
                    .setPath(path)
                    .setSaveFilename(filename)
                    .setContentType(contentType);
            if (isPrivate) {
                pretreatment.setPlatform(privatePlatform);
            }
            fileInfo = pretreatment.upload();
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
    public Optional<String> publicUrl(StoredObject object) {
        if (isPublicPlatform(object.platform())) {
            return Optional.of(publicDomain + fullObjectKey(object.objectKey()));
        }
        return Optional.empty();
    }

    @Override
    public String presignedUrl(StoredObject object, Instant expiresAt) {
        return generatePresignedUrl(fileInfo(object), expiresAt, portablePath(object.objectKey()));
    }

    @Override
    public Optional<String> presignedUrl(String sourceUrl, Instant expiresAt) {
        Optional<String> objectKey = objectKeyFromStorageUrl(sourceUrl);
        if (objectKey.isEmpty()) {
            return Optional.empty();
        }
        // 公开空间直链无需签名；私有空间生成下载凭证
        if (isPrivateStorageUrl(sourceUrl)) {
            StoredObject object = new StoredObject(privatePlatform, objectKey.get());
            return Optional.of(generatePresignedUrl(fileInfo(object), expiresAt, sourceUrl));
        }
        if (hostMatches(sourceUrl, publicDomain)) {
            return Optional.of(portablePath(objectKey.get()));
        }
        StoredObject object = new StoredObject(publicPlatform, objectKey.get());
        return Optional.of(generatePresignedUrl(fileInfo(object), expiresAt, portablePath(objectKey.get())));
    }

    @Override
    public String normalizeForPersistence(String sourceUrl) {
        if (!StringUtils.hasText(sourceUrl)) {
            return null;
        }
        String trimmed = sourceUrl.trim();
        Optional<String> objectKey = objectKeyFromStorageUrl(trimmed);
        if (objectKey.isEmpty()) {
            return trimmed;
        }
        // 私有地址保持原样（访问走预签名），公开地址归一化为 CDN 直链
        if (isPrivateStorageUrl(trimmed)) {
            return trimmed;
        }
        return portablePath(objectKey.get());
    }

    @Override
    public String portablePath(String objectKey) {
        return publicDomain + fullObjectKey(objectKey);
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

    private boolean isPublicPlatform(String platform) {
        return platform == null || platform.isBlank() || equalsIgnoreCase(platform, publicPlatform);
    }

    private boolean isPrivateStorageUrl(String sourceUrl) {
        return hostMatches(sourceUrl, privateDomain);
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

            // 1) 七牛 CDN 域名（公开/私有）：key 就是路径（无 bucket 前缀）
            if (hostMatches(sourceUrl, publicDomain) || hostMatches(sourceUrl, privateDomain)) {
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
            return Optional.empty();
        } catch (IllegalArgumentException ignored) {
            return Optional.empty();
        }
    }

    private String stripBucketPrefix(String path) {
        for (String bucket : new String[] {publicBucket, privateBucket}) {
            String prefix = bucket + "/";
            if (path.startsWith(prefix)) {
                return path.substring(prefix.length());
            }
        }
        return null;
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
