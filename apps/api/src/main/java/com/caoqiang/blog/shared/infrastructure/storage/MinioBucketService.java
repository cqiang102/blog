package com.caoqiang.blog.shared.infrastructure.storage;

import com.caoqiang.blog.shared.exception.BusinessException;
import io.minio.BucketExistsArgs;
import io.minio.MakeBucketArgs;
import io.minio.MinioClient;
import io.minio.errors.ErrorResponseException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.util.StringUtils;

/**
 * 确保对象存储的目标 bucket 已准备好。
 */
@Component
public class MinioBucketService {

    private static final Logger log = LoggerFactory.getLogger(MinioBucketService.class);

    private final MinioClient minioClient;
    private final String bucketName;

    public MinioBucketService(
            @Value("${dromara.x-file-storage.minio[0].end-point:http://localhost:9000}") String endpoint,
            @Value("${dromara.x-file-storage.minio[0].access-key:blog_minio}") String accessKey,
            @Value("${dromara.x-file-storage.minio[0].secret-key:blog_minio_password}") String secretKey,
            @Value("${dromara.x-file-storage.minio[0].bucket-name:blog-media}") String bucketName
    ) {
        this.bucketName = bucketName;
        this.minioClient = MinioClient.builder()
                .endpoint(endpoint)
                .credentials(accessKey, secretKey)
                .build();
    }

    public void ensureBucketExists() {
        if (!StringUtils.hasText(bucketName)) {
            throw new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "文件存储配置不完整");
        }

        try {
            boolean exists = minioClient.bucketExists(BucketExistsArgs.builder()
                    .bucket(bucketName)
                    .build());
            if (exists) {
                return;
            }

            minioClient.makeBucket(MakeBucketArgs.builder()
                    .bucket(bucketName)
                    .build());
            log.info("Created MinIO bucket: {}", bucketName);
        } catch (ErrorResponseException exception) {
            if ("BucketAlreadyOwnedByYou".equals(exception.errorResponse().code())) {
                return;
            }
            throw unavailable(exception);
        } catch (Exception exception) {
            throw unavailable(exception);
        }
    }

    private BusinessException unavailable(Exception exception) {
        log.warn("MinIO bucket is not available: {}", bucketName, exception);
        return new BusinessException(HttpStatus.SERVICE_UNAVAILABLE, "文件存储暂时不可用，请稍后重试");
    }
}
