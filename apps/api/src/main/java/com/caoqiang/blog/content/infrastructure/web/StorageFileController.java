package com.caoqiang.blog.content.infrastructure.web;

import com.caoqiang.blog.content.application.service.MediaAdminService;
import java.net.URI;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 对象存储文件访问控制器。
 *
 * <p>所有上传均为七牛私有对象，本端点按 key 生成短期预签名 URL 后 302 跳转。
 * 用于头像等未登记为媒体资源的对象引用（{@code /api/v1/storage/file?key=...}）。</p>
 */
@RestController
@RequestMapping("/api/v1/storage")
public class StorageFileController {

    private final MediaAdminService mediaAdminService;

    public StorageFileController(MediaAdminService mediaAdminService) {
        this.mediaAdminService = mediaAdminService;
    }

    @GetMapping("/file")
    public ResponseEntity<Void> file(@RequestParam("key") String key) {
        String presignedUrl = mediaAdminService.presignedUrlForKey(key);
        URI uri = URI.create(presignedUrl);
        return ResponseEntity.status(HttpStatus.FOUND)
                .header("Location", uri.toASCIIString())
                .build();
    }
}
