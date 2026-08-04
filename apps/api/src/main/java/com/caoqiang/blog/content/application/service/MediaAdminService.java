package com.caoqiang.blog.content.application.service;

import com.caoqiang.blog.content.application.dto.AdminContentResponse;
import com.caoqiang.blog.content.application.dto.AdminMediaRequest;
import com.caoqiang.blog.content.application.dto.AdminMediaResponse;
import com.caoqiang.blog.content.application.port.MediaStorage;
import com.caoqiang.blog.content.application.port.MediaStorage.StoredObject;
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import com.caoqiang.blog.content.domain.model.MediaReference;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.repository.MediaAssetRepository;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.model.UploadedFile;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.shared.util.PageUtils;
import com.caoqiang.blog.shared.util.TransactionCallbacks;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/**
 * 管理端媒体资源服务。
 * <p>
 * 位于博客系统的管理端业务层，负责媒体资源（图片、视频、文件）的全生命周期管理。
 * 核心职责：
 * <ul>
 *   <li>媒体资源列表查询（支持按内容 ID 过滤）</li>
 *   <li>通过应用层存储端口上传文件</li>
 *   <li>外链媒体资源的创建与管理</li>
 *   <li>媒体资源更新与事务提交后的存储清理</li>
 *   <li>设置内容封面图</li>
 * </ul>
 * 存储策略：本地上传文件存入配置的平台，外链媒体使用 "external" 伪 bucket。
 * 具体存储实现和部署地址由基础设施适配器负责。
 */
@Service
public class MediaAdminService {

    private static final Logger log = LoggerFactory.getLogger(MediaAdminService.class);

    /** 最大每页条数 */
    private static final int MAX_PAGE_SIZE = 80;

    private final MediaAssetRepository mediaAssetRepository;
    private final ContentRepository contentRepository;
    private final MediaStorage mediaStorage;
    private final MediaAssetWriter mediaAssetWriter;
    private final Clock clock;

    public MediaAdminService(
            MediaAssetRepository mediaAssetRepository,
            ContentRepository contentRepository,
            MediaStorage mediaStorage,
            MediaAssetWriter mediaAssetWriter,
            Clock clock) {
        this.mediaAssetRepository = mediaAssetRepository;
        this.contentRepository = contentRepository;
        this.mediaStorage = mediaStorage;
        this.mediaAssetWriter = mediaAssetWriter;
        this.clock = clock;
    }

    /**
     * 分页查询媒体资源列表，支持按内容 ID 过滤。
     *
     * @param contentId 内容 UUID（可为 null，不过滤时返回所有媒体）
     * @param page      页码，从 0 开始
     * @param size      每页条数，上限 {@link #MAX_PAGE_SIZE}
     * @return 分页媒体资源响应
     */
    @Transactional(readOnly = true)
    public PageResponse<AdminMediaResponse> list(UUID contentId, int page, int size) {
        PageRequest pageRequest = PageUtils.of(page, size, MAX_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "createdAt"));
        if (contentId != null) {
            Page<MediaAsset> result = mediaAssetRepository.findByContentId(contentId, pageRequest);
            return new PageResponse<>(
                    result.getContent().stream().map(AdminMediaResponse::from).toList(),
                    result.getNumber(),
                    result.getSize(),
                    result.getTotalElements());
        }

        Page<MediaAsset> result = mediaAssetRepository.findAll(pageRequest);
        return new PageResponse<>(
                result.getContent().stream().map(AdminMediaResponse::from).toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements());
    }

    /**
     * 上传文件到对象存储并创建媒体资源记录。
     * <p>
     * 处理流程：校验文件 → 推断媒体类型 → 生成路径 → 上传 → 保存数据库记录。
     *
     * @param contentId 所属内容 UUID（可为 null）
     * @param type      媒体类型（可为 null，自动推断）
     * @param file      上传的文件
     * @return 创建后的媒体资源响应
     * @throws BusinessException 文件为空或上传失败时抛出异常
     */
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    public AdminMediaResponse upload(UUID contentId, MediaAssetType type, UploadedFile file) {
        return upload(contentId, type, file, false);
    }

    /**
     * 上传文件到对象存储并创建媒体资源记录。
     *
     * @param contentId 所属内容 UUID（可为 null）
     * @param type      媒体类型（可为 null，自动推断）
     * @param file      上传的文件
     * @param isPrivate true 存入私有空间（lacia-private），false 存入公开空间（lacia-public）
     * @return 创建后的媒体资源响应
     */
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    public AdminMediaResponse upload(UUID contentId, MediaAssetType type, UploadedFile file, boolean isPrivate) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "请选择要上传的文件");
        }

        if (contentId != null && !contentRepository.existsById(contentId)) {
            throw new BusinessException(HttpStatus.NOT_FOUND, "内容不存在");
        }
        MediaAssetType mediaType = type == null ? inferType(file.contentType(), file.originalFilename()) : type;
        String filename = cleanFilename(file.originalFilename());
        String contentType =
                StringUtils.hasText(file.contentType()) ? file.contentType() : defaultContentType(mediaType);
        String path = datePath();

        StoredObject storedObject = mediaStorage.upload(file, path, filename, contentType, isPrivate);
        try {
            return mediaAssetWriter.createUploaded(
                    contentId, mediaType, storedObject, filename, contentType, file.size());
        } catch (RuntimeException exception) {
            deleteQuietly(storedObject, "failed media record creation");
            throw exception;
        }
    }

    /**
     * 获取媒体资源的预签名 URL。
     *
     * @param id 媒体资源 UUID
     * @return 预签名 URL
     */
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    public String getPresignedUrl(UUID id) {
        MediaAsset mediaAsset = mediaAssetRepository
                .findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "媒体资源不存在"));

        // 内部存储媒体：公开对象返回 CDN 直链，私有对象生成预签名 URL
        if (!MediaAsset.EXTERNAL_BUCKET.equals(mediaAsset.getBucket())) {
            StoredObject storedObject = storedObject(mediaAsset);
            return mediaStorage
                    .publicUrl(storedObject)
                    .orElseGet(() -> mediaStorage.presignedUrl(storedObject, presignedUrlExpiry()));
        }

        // 外链媒体：尝试解析存储 URL（兼容旧 MinIO 代理路径），否则原样返回
        String publicUrl = mediaAsset.getPublicUrl();
        if (publicUrl != null) {
            return mediaStorage.presignedUrl(publicUrl, presignedUrlExpiry()).orElse(publicUrl);
        }
        return publicUrl;
    }

    /**
     * 通用 URL 解析：将任意媒体 URL 转为可访问的预签名 URL。
     * <p>
     * 支持三种输入：
     * <ul>
     *   <li>代理路径 {@code /api/v1/media-assets/{id}/file} → 查库生成预签名</li>
     *   <li>存储直连 URL（七牛 CDN / 旧 MinIO 代理）→ 提取路径生成可访问 URL</li>
     *   <li>外部 URL → 原样返回</li>
     * </ul>
     *
     * @param url 媒体 URL（代理路径、直连 URL 或外部 URL）
     * @return 可直接访问的预签名 URL
     */
    @Transactional(propagation = Propagation.NOT_SUPPORTED)
    public String resolveUrl(String url) {
        if (url == null || url.isBlank()) {
            return url;
        }
        String trimmed = url.trim();

        // 代理路径：/api/v1/media-assets/{id}/file
        var mediaId = MediaReference.mediaId(trimmed);
        if (mediaId.isPresent()) {
            return getPresignedUrl(mediaId.get());
        }

        // 存储直链（公开 CDN / 私有签名 / 旧 MinIO 代理）
        return mediaStorage.presignedUrl(trimmed, presignedUrlExpiry()).orElse(trimmed);
    }

    /**
     * 将指向当前存储的 URL 规范化为可持久化路径（公开对象 → CDN 直链）。
     */
    public String normalizeStorageUrlForPersistence(String url) {
        return mediaStorage.normalizeForPersistence(url);
    }

    /**
     * 返回对象可持久化的公开地址（公开对象为 CDN 直链，私有对象调用方应走媒体端点）。
     */
    public String portableStoragePath(String objectKey) {
        return mediaStorage.portablePath(objectKey);
    }

    /**
     * 创建外链媒体资源记录（不上传文件到存储）。
     *
     * @param request 管理端媒体请求 DTO（必须包含 publicUrl）
     * @return 创建后的媒体资源响应
     */
    @Transactional
    public AdminMediaResponse create(AdminMediaRequest request) {
        Content content = content(request.contentId());
        MediaAsset mediaAsset = new MediaAsset(
                content,
                request.type() == null ? MediaAssetType.IMAGE : request.type(),
                MediaAsset.EXTERNAL_BUCKET,
                "external/" + UUID.randomUUID(),
                cleanRequired(request.publicUrl(), "媒体 URL 不能为空"),
                clean(request.filename()),
                clean(request.contentType()),
                request.byteSize(),
                request.width(),
                request.height(),
                request.durationSeconds());
        return AdminMediaResponse.from(mediaAssetRepository.save(mediaAsset));
    }

    /**
     * 更新媒体资源。
     * <p>
     * 若媒体被关联为某内容的封面，且所属内容发生变化，则自动清除原内容的封面关联。
     *
     * @param id      媒体资源 UUID
     * @param request 管理端媒体请求 DTO
     * @return 更新后的媒体资源响应
     * @throws BusinessException 媒体不存在时抛出 404
     */
    @Transactional
    public AdminMediaResponse update(UUID id, AdminMediaRequest request) {
        MediaAsset mediaAsset = mediaAssetRepository
                .findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "媒体资源不存在"));
        Content oldContent = mediaAsset.getContent();
        Content content = content(request.contentId());
        if (oldContent != null
                && oldContent.getCoverMedia() != null
                && oldContent.getCoverMedia().getId().equals(id)
                && (content == null || !oldContent.getId().equals(content.getId()))) {
            oldContent.setCoverMedia(null);
        }
        mediaAsset.update(
                content,
                request.type() == null ? mediaAsset.getType() : request.type(),
                mediaAsset.getBucket(),
                mediaAsset.getObjectKey(),
                cleanRequired(request.publicUrl(), "媒体 URL 不能为空"),
                clean(request.filename()),
                clean(request.contentType()),
                request.byteSize(),
                request.width(),
                request.height(),
                request.durationSeconds());
        return AdminMediaResponse.from(mediaAsset);
    }

    /**
     * 删除媒体资源。
     * <p>
     * 若该媒体是某内容的封面则清除封面引用，并在数据库事务提交后删除实际文件。
     *
     * @param id 媒体资源 UUID
     * @throws BusinessException 媒体不存在时抛出 404
     */
    @Transactional
    public void delete(UUID id) {
        MediaAsset mediaAsset = mediaAssetRepository
                .findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "媒体资源不存在"));
        Content content = mediaAsset.getContent();
        if (content != null
                && content.getBodyMarkdown() != null
                && content.getBodyMarkdown().contains(MediaReference.filePath(id))) {
            throw new BusinessException(HttpStatus.CONFLICT, "该媒体正在被内容正文引用，无法删除");
        }
        if (content != null
                && content.getCoverMedia() != null
                && content.getCoverMedia().getId().equals(id)) {
            content.setCoverMedia(null);
        }
        mediaAssetRepository.delete(mediaAsset);
        if (!MediaAsset.EXTERNAL_BUCKET.equals(mediaAsset.getBucket())) {
            StoredObject storedObject = storedObject(mediaAsset);
            TransactionCallbacks.afterCommit(() -> deleteQuietly(storedObject, "committed media deletion"));
        }
    }

    /**
     * 设置内容的封面媒体。
     *
     * @param contentId 内容 UUID
     * @param mediaId   媒体资源 UUID
     * @return 更新后的内容响应
     * @throws BusinessException 内容/媒体不存在，或媒体不属于该内容时抛出异常
     */
    @Transactional
    public AdminContentResponse setCover(UUID contentId, UUID mediaId) {
        Content content = contentRepository
                .findById(contentId)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
        MediaAsset mediaAsset = mediaAssetRepository
                .findById(mediaId)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "媒体资源不存在"));
        if (mediaAsset.getContent() == null || !mediaAsset.getContent().getId().equals(contentId)) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "封面媒体必须属于当前内容");
        }
        content.setCoverMedia(mediaAsset);
        return AdminContentResponse.from(content);
    }

    private Content content(UUID contentId) {
        if (contentId == null) {
            return null;
        }
        return contentRepository
                .findById(contentId)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
    }

    private String clean(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }

    private String cleanRequired(String value, String message) {
        if (!StringUtils.hasText(value)) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, message);
        }
        return value.trim();
    }

    private void deleteQuietly(StoredObject storedObject, String reason) {
        try {
            mediaStorage.delete(storedObject);
        } catch (Exception exception) {
            log.error(
                    "Failed to clean up stored media after {}: platform={}, objectKey={}",
                    reason,
                    storedObject.platform(),
                    storedObject.objectKey(),
                    exception);
        }
    }

    private StoredObject storedObject(MediaAsset mediaAsset) {
        return new StoredObject(mediaAsset.getBucket(), mediaAsset.getObjectKey());
    }

    private Instant presignedUrlExpiry() {
        return clock.instant().plus(Duration.ofDays(7));
    }

    /**
     * 生成按日期组织的路径，格式：yyyy/MM/dd/
     */
    private String datePath() {
        return LocalDate.now(clock).format(DateTimeFormatter.ofPattern("yyyy/MM/dd")) + "/";
    }

    private String cleanFilename(String value) {
        String filename = StringUtils.hasText(value) ? value.trim() : "upload";
        filename = filename.replaceAll("[\\\\/\\p{Cntrl}]+", "-");
        return filename.length() > 240 ? filename.substring(filename.length() - 240) : filename;
    }

    private MediaAssetType inferType(String contentType, String filename) {
        String type = contentType == null ? "" : contentType.toLowerCase(Locale.ROOT);
        String name = filename == null ? "" : filename.toLowerCase(Locale.ROOT);
        if (type.startsWith("video/") || name.endsWith(".mp4") || name.endsWith(".webm") || name.endsWith(".mov")) {
            return MediaAssetType.VIDEO;
        }
        if (type.startsWith("image/")
                || name.endsWith(".jpg")
                || name.endsWith(".jpeg")
                || name.endsWith(".png")
                || name.endsWith(".gif")
                || name.endsWith(".webp")) {
            return MediaAssetType.IMAGE;
        }
        return MediaAssetType.FILE;
    }

    private String defaultContentType(MediaAssetType type) {
        return switch (type) {
            case IMAGE -> "image/jpeg";
            case VIDEO -> "video/mp4";
            case FILE -> "application/octet-stream";
        };
    }
}
