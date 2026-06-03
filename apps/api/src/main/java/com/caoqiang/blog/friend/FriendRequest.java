package com.caoqiang.blog.friend;

import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/**
 * 友链请求 DTO
 * <p>
 * 用于创建或更新友链信息。
 * <p>
 * 包含参数校验：名称不能为空且最大 80 字符，网站 URL 不能为空，
 * 简介最大 1000 字符。
 *
 * @param name      友链名称，不能为空，最大 80 字符
 * @param avatarUrl 友链头像 URL
 * @param intro     友链简介，最大 1000 字符
 * @param siteUrl   友链网站 URL，不能为空
 * @param visible   是否可见
 * @param sortOrder 排序权重，数值越小越靠前
 */
public record FriendRequest(
        @NotBlank @Size(max = 80) String name,
        String avatarUrl,
        @Size(max = 1000) String intro,
        @NotBlank String siteUrl,
        boolean visible,
        int sortOrder
) {
}
