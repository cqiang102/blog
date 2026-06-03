package com.caoqiang.blog.content;

import java.io.InputStream;

/**
 * 媒体下载 DTO。
 * <p>
 * 封装从 MinIO 读取的媒体文件流及其元数据，由 {@link MediaAdminService#download} 生成，
 * 由 {@link MediaController#file} 消费并转换为 HTTP 响应。
 *
 * @param inputStream  文件输入流（调用方负责关闭）
 * @param filename     原始文件名
 * @param contentType  MIME 类型
 * @param byteSize     文件大小（字节）
 */
public record MediaDownload(
        InputStream inputStream,
        String filename,
        String contentType,
        Long byteSize
) {
}
