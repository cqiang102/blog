package com.caoqiang.blog.content.dto;

import com.caoqiang.blog.content.entity.Content;
import com.caoqiang.blog.content.entity.ContentStatus;
import com.caoqiang.blog.content.entity.ContentType;
import com.caoqiang.blog.content.entity.MediaAsset;
import com.caoqiang.blog.content.entity.MediaAssetType;
import com.caoqiang.blog.content.entity.Tag;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 标签请求 DTO。
 * <p>
 * 用于管理端创建和更新标签时的请求参数封装。
 * <p>
 * 验证规则：
 * <ul>
 *   <li>name：必填，最大 60 字符</li>
 *   <li>slug：可选，最大 80 字符（未提供时从 name 自动生成）</li>
 *   <li>description：可选，最大 1000 字符</li>
 * </ul>
 */
public record TagRequest(
        /** 标签名称（必填） */
        @NotBlank @Size(max = 60) String name,
        /** URL 标识符（可选，未提供时从 name 生成） */
        @Size(max = 80) String slug,
        /** 标签描述（可选） */
        @Size(max = 1000) String description
) {
}
