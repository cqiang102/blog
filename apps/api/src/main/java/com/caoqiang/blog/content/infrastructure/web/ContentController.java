package com.caoqiang.blog.content.infrastructure.web;

import com.caoqiang.blog.content.application.dto.ContentDetailResponse;
import com.caoqiang.blog.content.application.dto.ContentSummaryResponse;
import com.caoqiang.blog.content.application.dto.RecommendationResponse;
import com.caoqiang.blog.content.application.dto.TagResponse;
import com.caoqiang.blog.content.application.service.ContentQueryService;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.shared.model.AuthenticatedUser;
import com.caoqiang.blog.shared.response.ApiResponse;
import com.caoqiang.blog.shared.response.PageResponse;
import java.time.Instant;
import java.util.List;
import java.util.UUID;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 内容公开 REST 控制器。
 * <p>
 * 位于博客系统的公开 API 层，面向前端访客提供内容浏览接口。
 * 提供以下能力：
 * <ul>
 *   <li>内容列表查询（支持关键词搜索、标签过滤、类型过滤、时间范围过滤、分页）</li>
 *   <li>内容详情查看（包含当前用户是否已点赞的状态）</li>
 *   <li>推荐内容获取（置顶、最新、最热）</li>
 *   <li>全部标签列表</li>
 * </ul>
 * 所有接口均无需鉴权，属于公开可访问的只读接口。
 */
@RestController
@RequestMapping("/api/v1/contents")
public class ContentController {

    /** 内容业务服务，负责搜索、过滤、缓存推荐等核心逻辑 */
    private final ContentQueryService contentQueryService;

    public ContentController(ContentQueryService contentQueryService) {
        this.contentQueryService = contentQueryService;
    }

    /**
     * 获取推荐内容（置顶、最新、最热三组），结果走 Redis 缓存。
     *
     * @return 推荐内容响应，包含 pinned / latest / mostLiked 三个列表
     */
    @GetMapping("/recommendations")
    public ApiResponse<RecommendationResponse> recommendations() {
        return ApiResponse.ok(contentQueryService.recommendations());
    }

    /**
     * 分页查询已发布的内容列表，支持多条件组合过滤。
     *
     * @param query  搜索关键词，模糊匹配标题、摘要、正文
     * @param tag    标签 slug 列表，多标签取交集
     * @param type   内容类型过滤（ARTICLE / IMAGE / VIDEO）
     * @param from   发布时间起始（含）
     * @param to     发布时间截止（含）
     * @param page   页码，从 0 开始
     * @param size   每页条数，最大 50
     * @return 分页内容摘要列表
     */
    @GetMapping
    public ApiResponse<PageResponse<ContentSummaryResponse>> list(
            @RequestParam(required = false) String query,
            @RequestParam(required = false) List<String> tag,
            @RequestParam(required = false) ContentType type,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size) {
        return ApiResponse.ok(contentQueryService.list(query, tag, type, from, to, page, size));
    }

    /**
     * 获取内容详情，包含正文 Markdown、媒体资源列表、当前用户点赞状态等。
     *
     * @param id          内容 UUID
     * @param currentUser 当前登录用户（可为 null，未登录时 likedByCurrentUser 为 false）
     * @return 内容详情响应
     */
    @GetMapping("/{id}")
    public ApiResponse<ContentDetailResponse> detail(
            @PathVariable UUID id, @AuthenticationPrincipal AuthenticatedUser currentUser) {
        return ApiResponse.ok(contentQueryService.detail(id, currentUser));
    }

    /**
     * 获取全部标签列表，按名称排序。
     *
     * @return 标签响应列表
     */
    @GetMapping("/tags")
    public ApiResponse<List<TagResponse>> tags() {
        return ApiResponse.ok(contentQueryService.tags());
    }
}
