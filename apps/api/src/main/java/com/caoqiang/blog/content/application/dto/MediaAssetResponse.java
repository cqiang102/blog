package com.caoqiang.blog.content.application.dto;

import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import java.util.UUID;

/**
 * 媒体资源响应 DTO（公开接口）。
 * <p>
 * 用于公开接口中媒体资源的展示，仅包含前端渲染所需的字段。
 * 不暴露 bucket、objectKey 等存储内部细节。
 * <p>
 * 通过静态工厂方法 {@link #from(MediaAsset)} 从实体转换。
 */
public record MediaAssetResponse(
        /** 媒体资源 UUID */
        UUID id,
        /** 媒体类型 */
        MediaAssetType type,
        /** 公开访问 URL */
        String publicUrl,
        /** 原始文件名 */
        String filename,
        /** MIME 类型 */
        String contentType,
        /** 文件大小（字节） */
        Long byteSize,
        /** 宽度（像素） */
        Integer width,
        /** 高度（像素） */
        Integer height,
        /** 视频时长（秒） */
        Integer durationSeconds) {

    /**
     * 从 MediaAsset 实体转换为公开响应 DTO。
     *
     * @param mediaAsset 媒体资源实体
     * @return 媒体资源响应
     */
    public static MediaAssetResponse from(MediaAsset mediaAsset) {
        return new MediaAssetResponse(
                mediaAsset.getId(),
                mediaAsset.getType(),
                mediaAsset.getPublicUrl(),
                mediaAsset.getFilename(),
                mediaAsset.getContentType(),
                mediaAsset.getByteSize(),
                mediaAsset.getWidth(),
                mediaAsset.getHeight(),
                mediaAsset.getDurationSeconds());
    }
}
