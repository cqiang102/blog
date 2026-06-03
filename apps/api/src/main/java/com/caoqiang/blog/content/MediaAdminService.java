package com.caoqiang.blog.content;

import com.caoqiang.blog.common.BusinessException;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.config.BlogProperties;
import io.minio.BucketExistsArgs;
import io.minio.GetObjectArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.GetPresignedObjectUrlArgs;
import io.minio.RemoveObjectArgs;
import io.minio.http.Method;
import java.io.InputStream;
import java.net.URI;
import java.time.Clock;
import java.time.LocalDate;
import java.time.format.DateTimeFormatter;
import java.util.Locale;
import java.util.UUID;
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
 *   <li>文件上传到 MinIO 对象存储（自动生成按日期组织的 object key）</li>
 *   <li>外链媒体资源的创建与管理</li>
 *   <li>媒体资源的更新与删除（删除时同步清理 MinIO 中的文件）</li>
 *   <li>设置内容封面图</li>
 *   <li>文件下载代理（从 MinIO 读取文件流）</li>
 * </ul>
 * 存储策略：本地上传文件存入配置的 bucket，外链媒体使用 "external" 伪 bucket。
 */
@Service
public class MediaAdminService {

    /** 最大每页条数 */
    private static final int MAX_PAGE_SIZE = 80;

    /** 外链媒体使用的伪 bucket 名称 */
    private static final String EXTERNAL_BUCKET = "external";

    /** MinIO 分片上传的分片大小（10MB） */
    private static final long MINIO_PART_SIZE = 10L * 1024 * 1024;

    private final MediaAssetRepository mediaAssetRepository;
    private final ContentRepository contentRepository;
    private final MinioClient minioClient;
    private final BlogProperties blogProperties;
    private final Clock clock;

    public MediaAdminService(
            MediaAssetRepository mediaAssetRepository,
            ContentRepository contentRepository,
            MinioClient minioClient,
            BlogProperties blogProperties,
            Clock clock
    ) {
        this.mediaAssetRepository = mediaAssetRepository;
        this.contentRepository = contentRepository;
        this.minioClient = minioClient;
        this.blogProperties = blogProperties;
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
     * 上传文件到 MinIO 并创建媒体资源记录。
     * <p>
     * 处理流程：校验文件 → 推断媒体类型 → 生成 object key → 上传 MinIO → 保存数据库记录。
     *
     * @param contentId 所属内容 UUID（可为 null）
     * @param type      媒体类型（可为 null，自动推断）
     * @param file      上传的文件
     * @return 创建后的媒体资源响应
     * @throws BusinessException 文件为空、超过大小限制或上传失败时抛出异常
     */
    @Transactional
    public AdminMediaResponse upload(UUID contentId, MediaAssetType type, MultipartFile file) {
        if (file == null || file.isEmpty()) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "请选择要上传的文件");
        }
        long maxUploadBytes = blogProperties.getStorage().getMaxUploadBytes();
        if (file.getSize() > maxUploadBytes) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "文件超过上传大小限制");
        }

        Content content = content(contentId);
        // 未指定类型时根据 Content-Type 和文件名推断
        MediaAssetType mediaType = type == null ? inferType(file.getContentType(), file.getOriginalFilename()) : type;
        String filename = cleanFilename(file.getOriginalFilename());
        String contentType = StringUtils.hasText(file.getContentType())
                ? file.getContentType()
                : defaultContentType(mediaType);
        String bucket = blogProperties.getStorage().getBucket();
        String objectKey = objectKey(filename);
        uploadToMinio(bucket, objectKey, file, contentType);

        MediaAsset mediaAsset = new MediaAsset(
                content,
                mediaType,
                bucket,
                objectKey,
                null,
                filename,
                contentType,
                file.getSize(),
                null,
                null,
                null
        );
        // 上传完成后设置公开访问 URL
        mediaAsset.setPublicUrl(publicUrl(mediaAsset));
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
        return publicUrl(mediaAsset);
    }

    /**
     * 从 MinIO 下载媒体文件（代理读取）。
     * <p>
     * 外链媒体（bucket = "external"）不支持代理读取，直接抛出 404。
     *
     * @param id 媒体资源 UUID
     * @return 媒体下载 DTO，包含输入流、文件名、Content-Type、文件大小
     * @throws BusinessException 媒体不存在或为外链资源时抛出 404
     */
    @Transactional(readOnly = true)
    public MediaDownload download(UUID id) {
        MediaAsset mediaAsset = mediaAssetRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "媒体资源不存在"));
        if (EXTERNAL_BUCKET.equals(mediaAsset.getBucket())) {
            throw new BusinessException(HttpStatus.NOT_FOUND, "外链媒体不支持代理读取");
        }

        try {
            InputStream inputStream = minioClient.getObject(GetObjectArgs.builder()
                    .bucket(mediaAsset.getBucket())
                    .object(mediaAsset.getObjectKey())
                    .build());
            return new MediaDownload(
                    inputStream,
                    mediaAsset.getFilename(),
                    mediaAsset.getContentType(),
                    mediaAsset.getByteSize()
            );
        } catch (Exception exception) {
            throw new BusinessException(HttpStatus.NOT_FOUND, "媒体文件不存在");
        }
    }

    /**
     * 创建外链媒体资源记录（不上传文件到 MinIO）。
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
        // 如果媒体是旧内容的封面且内容发生变化，清除旧内容的封面引用
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
     * 同步清理：若该媒体是某内容的封面则清除封面引用，从 MinIO 删除实际文件。
     *
     * @param id 媒体资源 UUID
     * @throws BusinessException 媒体不存在时抛出 404
     */
    @Transactional
    public void delete(UUID id) {
        MediaAsset mediaAsset = mediaAssetRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "媒体资源不存在"));
        Content content = mediaAsset.getContent();
        // 若该媒体是所属内容的封面，先清除封面引用
        if (content != null && content.getCoverMedia() != null && content.getCoverMedia().getId().equals(id)) {
            content.setCoverMedia(null);
        }
        removeFromMinio(mediaAsset);
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
        // 校验媒体必须属于指定内容
        if (mediaAsset.getContent() == null || !mediaAsset.getContent().getId().equals(contentId)) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, "封面媒体必须属于当前内容");
        }
        content.setCoverMedia(mediaAsset);
        return AdminContentResponse.from(content);
    }

    /**
     * 根据 ID 查询内容实体，contentId 为 null 时返回 null。
     *
     * @param contentId 内容 UUID
     * @return 内容实体或 null
     * @throws BusinessException 内容不存在时抛出 404
     */
    private Content content(UUID contentId) {
        if (contentId == null) {
            return null;
        }
        return contentRepository.findById(contentId)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "内容不存在"));
    }

    /** 清理字符串值，空白时返回 null */
    private String clean(String value) {
        return StringUtils.hasText(value) ? value.trim() : null;
    }

    /** 清理并校验必填字符串，空白时抛出业务异常 */
    private String cleanRequired(String value, String message) {
        if (!StringUtils.hasText(value)) {
            throw new BusinessException(HttpStatus.BAD_REQUEST, message);
        }
        return value.trim();
    }

    /**
     * 上传文件到 MinIO。
     * <p>
     * 上传前自动检测并创建目标 bucket。
     *
     * @param bucket      目标 bucket
     * @param objectKey   对象 key
     * @param file        上传的文件
     * @param contentType MIME 类型
     * @throws BusinessException 上传失败时抛出 500
     */
    private void uploadToMinio(String bucket, String objectKey, MultipartFile file, String contentType) {
        try {
            ensureBucket(bucket);
            try (InputStream inputStream = file.getInputStream()) {
                minioClient.putObject(PutObjectArgs.builder()
                        .bucket(bucket)
                        .object(objectKey)
                        .stream(inputStream, file.getSize(), MINIO_PART_SIZE)
                        .contentType(contentType)
                        .build());
            }
        } catch (Exception exception) {
            throw new BusinessException(HttpStatus.INTERNAL_SERVER_ERROR, "上传媒体文件失败");
        }
    }

    /**
     * 从 MinIO 删除文件。
     * <p>
     * 外链媒体（bucket = "external"）无需删除实际文件。
     *
     * @param mediaAsset 媒体资源实体
     * @throws BusinessException 删除失败时抛出 500
     */
    private void removeFromMinio(MediaAsset mediaAsset) {
        if (EXTERNAL_BUCKET.equals(mediaAsset.getBucket())) {
            return;
        }
        try {
            minioClient.removeObject(RemoveObjectArgs.builder()
                    .bucket(mediaAsset.getBucket())
                    .object(mediaAsset.getObjectKey())
                    .build());
        } catch (Exception exception) {
            throw new BusinessException(HttpStatus.INTERNAL_SERVER_ERROR, "删除媒体文件失败");
        }
    }

    /** 确保 MinIO bucket 存在，不存在则创建 */
    private void ensureBucket(String bucket) throws Exception {
        boolean exists = minioClient.bucketExists(BucketExistsArgs.builder().bucket(bucket).build());
        if (!exists) {
            minioClient.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
        }
    }

    /**
     * 生成 MinIO 对象 key，格式：uploads/yyyy/MM/dd/UUID/filename
     *
     * @param filename 文件名
     * @return 对象 key
     */
    private String objectKey(String filename) {
        String datePath = LocalDate.now(clock).format(DateTimeFormatter.ofPattern("yyyy/MM/dd"));
        return "uploads/" + datePath + "/" + UUID.randomUUID() + "/" + filename;
    }

    /**
     * 生成媒体资源的预签名公开访问 URL。
     * <p>
     * 使用 MinIO 预签名机制生成带签名的临时 URL，浏览器可直接访问无需经过 API 服务器。
     * 如果配置了 {@code blog.storage.publicEndpoint}，会将 URL 中的内部地址替换为公开地址。
     *
     * @param mediaAsset 媒体资源实体
     * @return 预签名公开 URL
     */
    private String publicUrl(MediaAsset mediaAsset) {
        if (EXTERNAL_BUCKET.equals(mediaAsset.getBucket())) {
            return mediaAsset.getPublicUrl();
        }
        try {
            String url = minioClient.getPresignedObjectUrl(
                    GetPresignedObjectUrlArgs.builder()
                            .method(Method.GET)
                            .bucket(mediaAsset.getBucket())
                            .object(mediaAsset.getObjectKey())
                            .expiry(7 * 24 * 3600) // 7 天有效
                            .build());
            String publicEndpoint = blogProperties.getStorage().getPublicEndpoint();
            if (StringUtils.hasText(publicEndpoint)) {
                URI internal = URI.create(url);
                URI pub = URI.create(publicEndpoint);
                url = new URI(pub.getScheme(), pub.getAuthority(), internal.getPath(),
                        internal.getQuery(), internal.getFragment()).toString();
            }
            return url;
        } catch (Exception e) {
            throw new BusinessException(HttpStatus.INTERNAL_SERVER_ERROR, "生成文件访问链接失败");
        }
    }

    /**
     * 清理文件名：去除控制字符和路径分隔符，限制最大长度 240。
     *
     * @param value 原始文件名
     * @return 清理后的文件名
     */
    private String cleanFilename(String value) {
        String filename = StringUtils.hasText(value) ? value.trim() : "upload";
        filename = filename.replaceAll("[\\\\/\\p{Cntrl}]+", "-");
        return filename.length() > 240 ? filename.substring(filename.length() - 240) : filename;
    }

    /**
     * 根据 Content-Type 和文件名推断媒体类型。
     *
     * @param contentType MIME 类型
     * @param filename    文件名
     * @return 推断的媒体类型
     */
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

    /**
     * 根据媒体类型返回默认的 MIME 类型。
     *
     * @param type 媒体类型
     * @return 默认 MIME 类型
     */
    private String defaultContentType(MediaAssetType type) {
        return switch (type) {
            case IMAGE -> "image/jpeg";
            case VIDEO -> "video/mp4";
            case FILE -> "application/octet-stream";
        };
    }
}
