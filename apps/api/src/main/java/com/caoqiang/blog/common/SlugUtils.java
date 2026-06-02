package com.caoqiang.blog.common;

import java.util.Locale;
import java.util.UUID;

public final class SlugUtils {

    private SlugUtils() {
    }

    public static String from(String value) {
        String slug = value == null ? "" : value.trim().toLowerCase(Locale.ROOT)
                .replaceAll("[^a-z0-9\\u4e00-\\u9fa5]+", "-")
                .replaceAll("(^-+|-+$)", "");
        if (slug.isBlank()) {
            return UUID.randomUUID().toString();
        }
        return slug.length() > 80 ? slug.substring(0, 80).replaceAll("-+$", "") : slug;
    }
}
