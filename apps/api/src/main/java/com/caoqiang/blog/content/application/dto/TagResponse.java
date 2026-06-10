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
 * 标签响应 DTO。
 * <p>
 * 用于标签列表和详情的响应封装，同时被 {@link AdminContentResponse} 嵌套使用。
 * <p>
 * 通过静态工厂方法 {@link #from(Tag)} 从实体转换。
 */
public record TagResponse(
        /** 标签 UUID */
        UUID id,
        /** 标签名称 */
        String name,
        /** URL 标识符 */
        String slug,
        /** 标签描述 */
        String description,
        /** 创建时间 */
        Instant createdAt,
        /** 最后更新时间 */
        Instant updatedAt
) {

    /**
     * 从 Tag 实体转换为响应 DTO。
     *
     * @param tag 标签实体
     * @return 标签响应
     */
    public static TagResponse from(Tag tag) {
        return new TagResponse(
                tag.getId(),
                tag.getName(),
                tag.getSlug(),
                tag.getDescription(),
                tag.getCreatedAt(),
                tag.getUpdatedAt()
        );
    }
}
