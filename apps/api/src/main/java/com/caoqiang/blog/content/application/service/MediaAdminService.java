package com.caoqiang.blog.content.application.service;

import com.caoqiang.blog.content.application.dto.AdminContentRequest;
import com.caoqiang.blog.content.application.dto.AdminContentResponse;
import com.caoqiang.blog.content.application.dto.AdminMediaRequest;
import com.caoqiang.blog.content.application.dto.AdminMediaResponse;
import com.caoqiang.blog.content.application.dto.ContentDetailResponse;
import com.caoqiang.blog.content.application.dto.ContentSummaryResponse;
import com.caoqiang.blog.content.application.dto.MediaAssetResponse;
import com.caoqiang.blog.content.application.dto.RecommendationResponse;
import com.caoqiang.blog.content.application.dto.TagRequest;
import com.caoqiang.blog.content.application.dto.TagResponse;
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import com.caoqiang.blog.content.domain.model.Tag;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.repository.MediaAssetRepository;
import com.caoqiang.blog.content.domain.repository.TagRepository;

import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.shared.response.PageResponse;
import java.time.Clock;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.Date;
import java.util.Locale;
import java.util.UUID;
import org.dromara.x.file.storage.core.FileInfo;
import org.dromara.x.file.storage.core.FileStorageService;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;
import org.springframework.web.multipart.MultipartFile;

/**
 * 管理端媒体资源服务。
 * <p>
 * 位于博客系统的管理端业务层，负责媒体资源（图片、视频、文件）的全生命周期管理。
 * 核心职责：
 * <ul>
 *   <li>媒体资源列表查询（支持按内容 ID 过滤）</li>
 *   <li>文件上传到对象存储（通过 x-file-storage 统一抽象）</li>
 *   <li>外链媒体资源的创建与管理</li>
 *   <li>媒体资源的更新与删除（删除时同步清理存储中的文件）</li>
 *   <li>设置内容封面图</li>
 * </ul>
 * 存储策略：本地上传文件存入配置的平台，外链媒体使用 "external" 伪 bucket。
 * 通过 x-file-storage 抽象层支持 MinIO、AWS S3、阿里云 OSS 等多种存储平台。
 */
@Service
public class MediaAdminService {

    private static final Logger log = LoggerFactory.getLogger(MediaAdminService.class);

    /** 最大每页条数 */
    private static final int MAX_PAGE_SIZE = 80;

    /** 外链媒体使用的伪 bucket 名称 */
    private static final String EXTERNAL_BUCKET = "external";

    private final MediaAssetRepository mediaAssetRepository;
    private final ContentRepository contentRepository;
    private final FileStorageService fileStorageService;
    private final Clock clock;
    private final String minioEndpoint;

    public MediaAdminService(
            MediaAssetRepository mediaAssetRepository,
            ContentRepository contentRepository,
            FileStorageService fileStorageService,
            Clock clock,
            @Value("${dromara.x-file-storage.minio[0].end-point:http://localhost:9000}") String minioEndpoint
    ) {
        this.mediaAssetRepository = mediaAssetRepository;
        this.contentRepository = contentRepository;
        this.fileStorageService = fileStorageService;
        this.clock = clock;
        this.minioEndpoint = minioEndpoint;
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
        int safePage = Math.max(0, page);
        int safeSize = Math.max(1, Math.min(size, MAX_PAGE_SIZE));
        PageRequest pageRequest = PageRequest.of(safePage, safeSize, Sort.by(Sort.Direction.DESC, "createdAt"));
        if (contentId != null) {
            Page<MediaAsset> result = mediaAssetRepository.findByContentId(contentId, pageRequest);
            return new PageResponse<>(
                    result.getContent().stream()
                            .map(AdminMediaResponse::from)
                            .toList(),
                    result.getNumber(),
                    result.getSize(),
                    result.getTotalElements()
            );
        }

        Page<MediaAsset> result = mediaAssetRepository.findAll(pageRequest);
        return new PageResponse<>(
                result.getContent().stream().map(AdminMediaResponse::from).toList(),
                result.getNumber(),
                result.getSize(),
                result.getTotalElements()
        );
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
    @Transactional
    public AdminMediaResponse upload(UUID contentId, MediaAssetType type, MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "请选择要上传的文件");
        }

        Content content = content(contentId);
        MediaAssetType mediaType = type == null ? inferType(file.getContentType(), file.getOriginalFilename()) : type;
        String filename = cleanFilename(file.getOriginalFilename());
        String contentType = StringUtils.hasText(file.getContentType())
                ? file.getContentType()
                : defaultContentType(mediaType);
        String path = datePath();

        FileInfo fileInfo = fileStorageService.of(file)
                .setPath(path)
                .setSaveFilename(filename)
                .setContentType(contentType)
                .upload();

        MediaAsset mediaAsset = new MediaAsset(
                content,
                mediaType,
                fileInfo.getPlatform(),
                fileInfo.getPath() + fileInfo.getFilename(),
                fileInfo.getUrl(),
                filename,
                contentType,
                file.getSize(),
                null,
                null,
                null
        );
        return AdminMediaResponse.from(mediaAssetRepository.save(mediaAsset));
    }

    /**
     * 获取媒体资源的预签名 URL。
     *
     * @param id 媒体资源 UUID
     * @return 预签名 URL
     */
    @Transactional(readOnly = true)
    public String getPresignedUrl(UUID id) {
        MediaAsset mediaAsset = mediaAssetRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "媒体资源不存在"));

        // 内部存储媒体：直接生成预签名
        if (!EXTERNAL_BUCKET.equals(mediaAsset.getBucket())) {
            return generatePresignedUrl(buildFileInfo(mediaAsset), mediaAsset.getPublicUrl());
        }

        // 外链媒体：尝试用默认平台生成预签名（URL 指向本机 MinIO 的场景）
        String publicUrl = mediaAsset.getPublicUrl();
        if (publicUrl != null) {
            String presigned = tryPresignExternalUrl(publicUrl);
            if (presigned != null) {
                return presigned;
            }
        }
        return publicUrl;
    }

    /**
     * 通用 URL 解析：将任意媒体 URL 转为可访问的预签名 URL。
     * <p>
     * 支持三种输入：
     * <ul>
     *   <li>代理路径 {@code /api/v1/media-assets/{id}/file} → 查库生成预签名</li>
     *   <li>本机 MinIO 直连 URL → 提取路径生成预签名</li>
     *   <li>外部 URL → 原样返回</li>
     * </ul>
     *
     * @param url 媒体 URL（代理路径、直连 URL 或外部 URL）
     * @return 可直接访问的预签名 URL
     */
    public String resolveUrl(String url) {
        if (url == null || url.isBlank()) {
            return url;
        }
        String trimmed = url.trim();

        // 代理路径：/api/v1/media-assets/{id}/file
        java.util.Optional<UUID> mediaId = com.caoqiang.blog.content.domain.model.MediaReference.mediaId(trimmed);
        if (mediaId.isPresent()) {
            try {
                return getPresignedUrl(mediaId.get());
            } catch (Exception e) {
                log.debug("Failed to presign media {}: {}", mediaId.get(), e.getMessage());
                return trimmed;
            }
        }

        // 本机 MinIO 直连 URL
        String presigned = tryPresignExternalUrl(trimmed);
        if (presigned != null) {
            return presigned;
        }

        // 外部 URL 或无法识别的格式
        return trimmed;
    }

    /**
     * 为外链 URL 生成预签名。
     * 如果 URL 指向本机 MinIO，提取路径后用默认平台生成预签名。
     */
    private String tryPresignExternalUrl(String url) {
        try {
            java.net.URI uri = java.net.URI.create(url);
            String host = uri.getHost();
            int port = uri.getPort() > 0 ? uri.getPort() : ("https".equals(uri.getScheme()) ? 443 : 80);
            // 比较 endpoint 的 host:port
            java.net.URI endpointUri = java.net.URI.create(minioEndpoint);
            String endpointHost = endpointUri.getHost();
            int endpointPort = endpointUri.getPort() > 0 ? endpointUri.getPort()
                    : ("https".equals(endpointUri.getScheme()) ? 443 : 80);

            if (!equalsIgnoreCase(host, endpointHost) || port != endpointPort) {
                return null; // 非本机 MinIO，无法生成预签名
            }

            String path = uri.getPath(); // e.g. /uploads/2026/06/10/file.jpeg
            if (path == null || path.isEmpty()) return null;
            // 去掉开头的 /
            if (path.startsWith("/")) path = path.substring(1);
            int lastSlash = path.lastIndexOf('/');
            if (lastSlash < 0) return null;

            String dir = path.substring(0, lastSlash + 1);
            String filename = path.substring(lastSlash + 1);

            FileInfo fileInfo = new FileInfo();
            fileInfo.setPlatform("minio-1");
            fileInfo.setPath(dir);
            fileInfo.setFilename(filename);
            fileInfo.setUrl(url);

            String presigned = generatePresignedUrl(fileInfo, null);
            log.debug("Presigned external URL: {} -> {}", url, presigned);
            return presigned;
        } catch (Exception e) {
            log.debug("Failed to presign external URL: {}", url, e);
            return null;
        }
    }

    private String generatePresignedUrl(FileInfo fileInfo, String fallbackUrl) {
        LocalDateTime expiry = LocalDateTime.now(clock).plusDays(7);
        Date expiryDate = Date.from(expiry.atZone(ZoneId.systemDefault()).toInstant());
        String url = fileStorageService.generatePresignedUrl(fileInfo, expiryDate);
        if (url == null) {
            log.warn("generatePresignedUrl returned null, platform={}, path={}, filename={}",
                    fileInfo.getPlatform(), fileInfo.getPath(), fileInfo.getFilename());
        }
        return url != null ? url : fallbackUrl;
    }

    private static boolean equalsIgnoreCase(String a, String b) {
        return a != null && b != null && a.equalsIgnoreCase(b);
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
                EXTERNAL_BUCKET,
                "external/" + UUID.randomUUID(),
                cleanRequired(request.publicUrl(), "媒体 URL 不能为空"),
                clean(request.filename()),
                clean(request.contentType()),
                request.byteSize(),
                request.width(),
                request.height(),
                request.durationSeconds()
        );
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
        MediaAsset mediaAsset = mediaAssetRepository.findById(id)
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
                request.durationSeconds()
        );
        return AdminMediaResponse.from(mediaAsset);
    }

    /**
     * 删除媒体资源。
     * <p>
     * 同步清理：若该媒体是某内容的封面则清除封面引用，从存储中删除实际文件。
     *
     * @param id 媒体资源 UUID
     * @throws BusinessException 媒体不存在时抛出 404
     */
    @Transactional
    public void delete(UUID id) {
        MediaAsset mediaAsset = mediaAssetRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "媒体资源不存在"));
        Content content = mediaAsset.getContent();
        if (content != null && content.getCoverMedia() != null && content.getCoverMedia().getId().equals(id)) {
            content.setCoverMedia(null);
        }
        removeFromStorage(mediaAsset);
        mediaAssetRepository.delete(mediaAsset);
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
        Content content = contentRepository.findById(contentId)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
        MediaAsset mediaAsset = mediaAssetRepository.findById(mediaId)
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
        return contentRepository.findById(contentId)
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

    /**
     * 从对象存储中删除文件。外链媒体无需删除。
     */
    private void removeFromStorage(MediaAsset mediaAsset) {
        if (EXTERNAL_BUCKET.equals(mediaAsset.getBucket())) {
            return;
        }
        try {
            FileInfo fileInfo = buildFileInfo(mediaAsset);
            fileStorageService.delete(fileInfo);
        } catch (Exception exception) {
            throw new BusinessException(HttpStatus.INTERNAL_SERVER_ERROR, "删除媒体文件失败");
        }
    }

    /**
     * 根据 MediaAsset 构建 FileInfo，用于 x-file-storage 操作。
     */
    private FileInfo buildFileInfo(MediaAsset mediaAsset) {
        FileInfo fileInfo = new FileInfo();
        fileInfo.setPlatform(mediaAsset.getBucket());
        fileInfo.setPath(mediaAsset.getObjectKey().substring(0, mediaAsset.getObjectKey().lastIndexOf('/') + 1));
        fileInfo.setFilename(mediaAsset.getObjectKey().substring(mediaAsset.getObjectKey().lastIndexOf('/') + 1));
        fileInfo.setUrl(mediaAsset.getPublicUrl());
        return fileInfo;
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
