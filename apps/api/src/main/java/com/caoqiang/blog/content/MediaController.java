package com.caoqiang.blog.content;

import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.UUID;
import org.springframework.core.io.InputStreamResource;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.util.StringUtils;

/**
 * 媒体资源下载控制器。
 * <p>
 * 位于博客系统的公开 API 层，提供媒体文件的 HTTP 代理下载能力。
 * 通过 URL 中的 UUID 定位媒体资源，从 MinIO 读取文件流并以 HTTP 响应返回。
 * <p>
 * 响应头设置：
 * <ul>
 *   <li>Content-Type：根据媒体资源的 MIME 类型设置</li>
 *   <li>Content-Disposition: inline，支持浏览器内联预览</li>
 *   <li>Content-Length：文件大小（若已知）</li>
 * </ul>
 */
@RestController
@RequestMapping("/api/v1/media-assets")
public class MediaController {

    private final MediaAdminService mediaAdminService;

    public MediaController(MediaAdminService mediaAdminService) {
        this.mediaAdminService = mediaAdminService;
    }

    /**
     * 代理下载媒体文件。
     * <p>
     * 文件名会进行 URL 编码以支持中文等非 ASCII 字符。
     *
     * @param id 媒体资源 UUID
     * @return 包含文件流的 HTTP 响应
     */
    @GetMapping("/{id}/file")
    public ResponseEntity<InputStreamResource> file(@PathVariable UUID id) {
        MediaDownload download = mediaAdminService.download(id);
        // 对文件名进行 URL 编码，空格编码为 %20
        String filename = StringUtils.hasText(download.filename()) ? download.filename() : id.toString();
        String encodedFilename = URLEncoder.encode(filename, StandardCharsets.UTF_8).replace("+", "%20");
        MediaType mediaType = StringUtils.hasText(download.contentType())
                ? MediaType.parseMediaType(download.contentType())
                : MediaType.APPLICATION_OCTET_STREAM;

        ResponseEntity.BodyBuilder response = ResponseEntity.ok()
                .contentType(mediaType)
                .header(HttpHeaders.CONTENT_DISPOSITION, "inline; filename=\"" + encodedFilename + "\"");
        if (download.byteSize() != null) {
            response.contentLength(download.byteSize());
        }
        return response.body(new InputStreamResource(download.inputStream()));
    }
}
