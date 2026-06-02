package com.caoqiang.blog.content;

import com.caoqiang.blog.common.BusinessException;
import com.caoqiang.blog.common.PageResponse;
import com.caoqiang.blog.config.BlogProperties;
import io.minio.BucketExistsArgs;
import io.minio.GetObjectArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.PutObjectArgs;
import io.minio.RemoveObjectArgs;
import java.io.InputStream;
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

@Service
public class MediaAdminService {

    private static final int MAX_PAGE_SIZE = 80;
    private static final String EXTERNAL_BUCKET = "external";
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
        mediaAsset.setPublicUrl(publicUrl(mediaAsset.getId()));
        return AdminMediaResponse.from(mediaAssetRepository.save(mediaAsset));
    }

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

    @Transactional
    public void delete(UUID id) {
        MediaAsset mediaAsset = mediaAssetRepository.findById(id)
                .orElseThrow(() -> new BusinessException(HttpStatus.NOT_FOUND, "媒体资源不存在"));
        Content content = mediaAsset.getContent();
        if (content != null && content.getCoverMedia() != null && content.getCoverMedia().getId().equals(id)) {
            content.setCoverMedia(null);
        }
        removeFromMinio(mediaAsset);
        mediaAssetRepository.delete(mediaAsset);
    }

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

    private void ensureBucket(String bucket) throws Exception {
        boolean exists = minioClient.bucketExists(BucketExistsArgs.builder().bucket(bucket).build());
        if (!exists) {
            minioClient.makeBucket(MakeBucketArgs.builder().bucket(bucket).build());
        }
    }

    private String objectKey(String filename) {
        String datePath = LocalDate.now(clock).format(DateTimeFormatter.ofPattern("yyyy/MM/dd"));
        return "uploads/" + datePath + "/" + UUID.randomUUID() + "/" + filename;
    }

    private String publicUrl(UUID id) {
        String baseUrl = blogProperties.getStorage().getPublicBaseUrl();
        String cleanBaseUrl = baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length() - 1) : baseUrl;
        return cleanBaseUrl + "/api/v1/media-assets/" + id + "/file";
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
