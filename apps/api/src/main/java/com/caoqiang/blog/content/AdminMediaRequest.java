package com.caoqiang.blog.content;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.util.UUID;

/**
 * 管理端媒体请求 DTO。
 * <p>
 * 用于管理端创建和更新外链媒体资源时的请求参数封装。
 * 本地文件上传不使用此 DTO，而是通过 MultipartFile 直接传输。
 */
public record AdminMediaRequest(
        /** 所属内容 UUID（可为 null） */
        UUID contentId,
        /** 媒体类型（可选，默认 IMAGE） */
        MediaAssetType type,
        /** 媒体公开访问 URL（必填） */
        @NotBlank String publicUrl,
        /** 原始文件名 */
        @Size(max = 240) String filename,
        /** MIME 类型 */
        @Size(max = 120) String contentType,
        /** 文件大小（字节） */
        Long byteSize,
        /** 宽度（像素） */
        Integer width,
        /** 高度（像素） */
        Integer height,
        /** 视频时长（秒） */
        Integer durationSeconds
) {
}
