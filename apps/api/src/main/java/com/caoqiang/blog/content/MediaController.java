package com.caoqiang.blog.content;

import com.caoqiang.blog.content.service.MediaAdminService;

import com.caoqiang.blog.content.dto.ContentDetailResponse;
import com.caoqiang.blog.content.dto.ContentSummaryResponse;
import com.caoqiang.blog.content.dto.MediaAssetResponse;
import com.caoqiang.blog.content.dto.RecommendationResponse;
import com.caoqiang.blog.content.entity.Content;
import com.caoqiang.blog.content.entity.ContentStatus;
import com.caoqiang.blog.content.entity.ContentType;
import com.caoqiang.blog.content.entity.MediaAsset;
import com.caoqiang.blog.content.entity.MediaAssetType;
import com.caoqiang.blog.content.entity.Tag;
import com.caoqiang.blog.content.repository.ContentRepository;
import com.caoqiang.blog.content.repository.MediaAssetRepository;
import com.caoqiang.blog.content.repository.TagRepository;
import com.caoqiang.blog.content.service.ContentService;

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
 * 前端通常直接使用预签名 URL 访问 MinIO，此端点仅作兼容保留。
 */
@RestController
@RequestMapping("/api/v1/media-assets")
public class MediaController {

    private final MediaAdminService mediaAdminService;

    public MediaController(MediaAdminService mediaAdminService) {
        this.mediaAdminService = mediaAdminService;
    }

    /**
     * 重定向到 MinIO 预签名 URL。
     *
     * @param id 媒体资源 UUID
     * @return 302 重定向到预签名 URL
     */
    @GetMapping("/{id}/file")
    public ResponseEntity<Void> file(@PathVariable UUID id) {
        String presignedUrl = mediaAdminService.getPresignedUrl(id);
        return ResponseEntity.status(HttpStatus.FOUND)
                .header("Location", presignedUrl)
                .build();
    }
}
