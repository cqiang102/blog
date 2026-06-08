package com.caoqiang.blog.admin;

import com.caoqiang.blog.shared.response.ApiResponse;
import com.caoqiang.blog.shared.response.OperationResult;
import com.caoqiang.blog.shared.response.PageResponse;
import com.caoqiang.blog.content.AdminContentResponse;
import com.caoqiang.blog.content.AdminMediaRequest;
import com.caoqiang.blog.content.AdminMediaResponse;
import com.caoqiang.blog.content.MediaAssetType;
import com.caoqiang.blog.content.MediaAdminService;
import jakarta.validation.Valid;
import java.util.UUID;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * 管理端媒体 CRUD 控制器
 * <p>
 * 提供管理员对媒体资源的完整 CRUD 操作，包括：
 * <ul>
 *   <li>媒体资源列表查询（支持按内容 ID 筛选）</li>
 *   <li>创建媒体资源（手动录入）</li>
 *   <li>上传媒体资源（文件上传）</li>
 *   <li>更新媒体资源信息</li>
 *   <li>删除媒体资源</li>
 *   <li>设置内容封面图</li>
 * </ul>
 * <p>
 * 所有端点均需管理员身份认证。
 * 基础路径: {@code /api/v1/admin}
 */
@RestController
@RequestMapping("/api/v1/admin")
public class AdminMediaController {

    /** 媒体管理服务 */
    private final MediaAdminService mediaAdminService;

    public AdminMediaController(MediaAdminService mediaAdminService) {
        this.mediaAdminService = mediaAdminService;
    }

    /**
     * 获取媒体资源列表（分页）
     *
     * @param contentId 内容 ID 筛选条件，可选
     * @param page      页码，从 0 开始
     * @param size      每页大小，默认 50
     * @return 媒体资源列表分页响应
     */
    @GetMapping("/media-assets")
    public ApiResponse<PageResponse<AdminMediaResponse>> list(
            @RequestParam(required = false) UUID contentId,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "50") int size
    ) {
        return ApiResponse.ok(mediaAdminService.list(contentId, page, size));
    }

    /**
     * 创建媒体资源（手动录入）
     *
     * @param request 媒体资源请求体
     * @return 创建后的媒体资源响应 DTO
     */
    @PostMapping("/media-assets")
    public ApiResponse<AdminMediaResponse> create(@Valid @RequestBody AdminMediaRequest request) {
        return ApiResponse.ok(mediaAdminService.create(request));
    }

    /**
     * 上传媒体资源（文件上传）
     * <p>
     * 支持图片、视频等文件上传，自动存储并返回资源信息。
     *
     * @param contentId 关联的内容 ID，可选
     * @param type      媒体资源类型，可选
     * @param file      上传的文件
     * @return 上传后的媒体资源响应 DTO
     */
    @PostMapping(value = "/media-assets/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ApiResponse<AdminMediaResponse> upload(
            @RequestParam(required = false) UUID contentId,
            @RequestParam(required = false) MediaAssetType type,
            @RequestParam("file") MultipartFile file
    ) {
        return ApiResponse.ok(mediaAdminService.upload(contentId, type, file));
    }

    /**
     * 更新媒体资源信息
     *
     * @param id      媒体资源 ID
     * @param request 媒体资源请求体
     * @return 更新后的媒体资源响应 DTO
     */
    @PutMapping("/media-assets/{id}")
    public ApiResponse<AdminMediaResponse> update(@PathVariable UUID id, @Valid @RequestBody AdminMediaRequest request) {
        return ApiResponse.ok(mediaAdminService.update(id, request));
    }

    /**
     * 删除媒体资源
     *
     * @param id 媒体资源 ID
     * @return 操作结果
     */
    @DeleteMapping("/media-assets/{id}")
    public ApiResponse<OperationResult> delete(@PathVariable UUID id) {
        mediaAdminService.delete(id);
        return ApiResponse.ok(OperationResult.deleted(id));
    }

    /**
     * 设置内容封面图
     * <p>
     * 将指定媒体资源设置为内容的封面图。
     *
     * @param contentId 内容 ID
     * @param mediaId   媒体资源 ID
     * @return 更新后的内容详情响应 DTO
     */
    @PutMapping("/contents/{contentId}/cover/{mediaId}")
    public ApiResponse<AdminContentResponse> setCover(@PathVariable UUID contentId, @PathVariable UUID mediaId) {
        return ApiResponse.ok(mediaAdminService.setCover(contentId, mediaId));
    }
}
