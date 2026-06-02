package com.caoqiang.blog.content;

import java.io.InputStream;

public record MediaDownload(
        InputStream inputStream,
        String filename,
        String contentType,
        Long byteSize
) {
}
