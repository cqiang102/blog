package com.caoqiang.blog.content.application.dto;

import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import com.caoqiang.blog.content.domain.model.Tag;

import java.time.Instant;
import java.util.UUID;

/**
 * 管理端媒体响应 DTO。
 * <p>
 * 用于管理端媒体列表和详情的响应封装。
 * 相比公开接口的 {@link MediaAssetResponse}，额外包含 bucket、objectKey、所属内容信息、是否为封面等管理字段。
 * <p>
 * 通过静态工厂方法 {@link #from(MediaAsset)} 从实体转换。
 */
public record AdminMediaResponse(
        /** 媒体资源 UUID */
        UUID id,
        /** 所属内容 UUID（可为 null） */
        UUID contentId,
        /** 所属内容标题（可为 null） */
        String contentTitle,
        /** 媒体类型 */
        MediaAssetType type,
        /** 存储 bucket */
        String bucket,
        /** MinIO 对象 key */
        String objectKey,
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
        Integer durationSeconds,
        /** 是否为所属内容的封面 */
        boolean cover,
        /** 创建时间 */
        Instant createdAt
) {

    /**
     * 从 MediaAsset 实体转换为管理端响应 DTO。
     * <p>
     * 自动判断该媒体是否为所属内容的封面。
     *
     * @param mediaAsset 媒体资源实体
     * @return 管理端媒体响应
     */
    public static AdminMediaResponse from(MediaAsset mediaAsset) {
        Content content = mediaAsset.getContent();
        // 判断该媒体是否为所属内容的封面
        boolean cover = content != null
                && content.getCoverMedia() != null
                && content.getCoverMedia().getId().equals(mediaAsset.getId());
        return new AdminMediaResponse(
                mediaAsset.getId(),
                content == null ? null : content.getId(),
                content == null ? null : content.getTitle(),
                mediaAsset.getType(),
                mediaAsset.getBucket(),
                mediaAsset.getObjectKey(),
                mediaAsset.getPublicUrl(),
                mediaAsset.getFilename(),
                mediaAsset.getContentType(),
                mediaAsset.getByteSize(),
                mediaAsset.getWidth(),
                mediaAsset.getHeight(),
                mediaAsset.getDurationSeconds(),
                cover,
                mediaAsset.getCreatedAt()
        );
    }
}
