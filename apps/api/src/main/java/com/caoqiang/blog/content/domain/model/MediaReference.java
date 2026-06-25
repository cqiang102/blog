package com.caoqiang.blog.content.domain.model;

import java.net.URI;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Markdown 中的稳定媒体引用。
 *
 * <p>正文只保存媒体 ID 路径，不保存有过期时间的预签名 URL。访问文件时由公开
 * 媒体端点动态重定向到最新的预签名地址。</p>
 */
public final class MediaReference {

    private static final Pattern FILE_PATH = Pattern.compile(
            "^/api/v1/media-assets/([0-9a-fA-F-]{36})/file/?$"
    );

    private MediaReference() {
    }

    public static String filePath(UUID mediaId) {
        return "/api/v1/media-assets/" + mediaId + "/file";
    }

    public static Optional<UUID> mediaId(String value) {
        if (value == null || value.isBlank()) {
            return Optional.empty();
        }
        try {
            String path = URI.create(value.trim()).getPath();
            Matcher matcher = FILE_PATH.matcher(path);
            if (!matcher.matches()) {
                return Optional.empty();
            }
            return Optional.of(UUID.fromString(matcher.group(1)));
        } catch (IllegalArgumentException ignored) {
            return Optional.empty();
        }
    }

    public static String normalizeMarkdown(
            String markdown,
            List<MediaAsset> mediaAssets
    ) {
        if (markdown == null || markdown.isBlank()) {
            return markdown;
        }
        String normalized = markdown;
        for (MediaAsset mediaAsset : mediaAssets) {
            String replacement = filePath(mediaAsset.getId());
            for (String reference : references(mediaAsset)) {
                normalized = normalized.replace(reference, replacement);
            }
        }
        return normalized;
    }

    private static List<String> references(MediaAsset mediaAsset) {
        List<String> references = new ArrayList<>();
        if (hasText(mediaAsset.getPublicUrl())) {
            references.add(mediaAsset.getPublicUrl());
        }
        if (!MediaAsset.EXTERNAL_BUCKET.equals(mediaAsset.getBucket())
                && hasText(mediaAsset.getBucket())
                && hasText(mediaAsset.getObjectKey())) {
            references.add("/minio/"
                    + stripSlashes(mediaAsset.getBucket())
                    + "/"
                    + stripSlashes(mediaAsset.getObjectKey()));
        }
        return references;
    }

    private static String stripSlashes(String value) {
        return value.replaceAll("^/+", "").replaceAll("/+$", "");
    }

    private static boolean hasText(String value) {
        return value != null && !value.isBlank();
    }
}
