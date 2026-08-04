package com.caoqiang.blog.content.infrastructure.web;

import com.caoqiang.blog.content.application.service.MediaAdminService;
import java.net.URI;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 媒体资源下载控制器。
 * <p>
 * 位于博客系统的公开 API 层，提供媒体文件的重定向访问。
 * 前端使用稳定的同源媒体路径，此端点按请求动态生成短期可用的存储地址。
 */
@RestController
@RequestMapping("/api/v1/media-assets")
public class MediaController {

    private final MediaAdminService mediaAdminService;

    public MediaController(MediaAdminService mediaAdminService) {
        this.mediaAdminService = mediaAdminService;
    }

    /**
     * 重定向到对象存储可访问 URL（公开直链或私有预签名）。
     *
     * @param id 媒体资源 UUID
     * @return 302 重定向到公开直链或预签名 URL
     */
    @GetMapping("/{id}/file")
    public ResponseEntity<Void> file(@PathVariable UUID id) {
        String presignedUrl = mediaAdminService.getPresignedUrl(id);
        // 将 URL 转为 ASCII 安全格式，避免中文字符导致 Location 头无效
        URI uri = URI.create(presignedUrl);
        String asciiUrl = uri.toASCIIString();
        return ResponseEntity.status(HttpStatus.FOUND)
                .header("Location", asciiUrl)
                .build();
    }
}
