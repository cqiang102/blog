package com.caoqiang.blog.config;

import io.minio.MinioClient;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * MinIO 对象存储客户端配置类。
 * <p>
 * 根据 {@link BlogProperties.Storage} 中的连接信息创建 {@link MinioClient} 单例，
 * 供媒体资源（图片、文件）的上传、下载、删除等操作使用。
 *
 * @author caoqiang
 */
@Configuration
public class StorageConfig {

    /**
     * 创建 MinIO 客户端 Bean。
     * <p>
     * 连接参数（endpoint、accessKey、secretKey）从 {@code blog.storage.*} 配置项中读取。
     *
     * @param blogProperties 博客全局配置属性
     * @return 配置完成的 MinioClient 实例
     */
    @Bean
    MinioClient minioClient(BlogProperties blogProperties) {
        BlogProperties.Storage storage = blogProperties.getStorage();
        return MinioClient.builder()
                .endpoint(storage.getEndpoint())
                .credentials(storage.getAccessKey(), storage.getSecretKey())
                .build();
    }
}
