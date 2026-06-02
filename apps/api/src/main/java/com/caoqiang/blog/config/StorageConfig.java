package com.caoqiang.blog.config;

import io.minio.MinioClient;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
public class StorageConfig {

    @Bean
    MinioClient minioClient(BlogProperties blogProperties) {
        BlogProperties.Storage storage = blogProperties.getStorage();
        return MinioClient.builder()
                .endpoint(storage.getEndpoint())
                .credentials(storage.getAccessKey(), storage.getSecretKey())
                .build();
    }
}
