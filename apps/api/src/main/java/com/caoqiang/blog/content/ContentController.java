package com.caoqiang.blog.content;

import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.PageResponse;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.format.annotation.DateTimeFormat;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/v1/contents")
public class ContentController {

    @GetMapping("/recommendations")
    public ApiResponse<RecommendationResponse> recommendations() {
        List<ContentSummary> samples = sampleContents();
        return ApiResponse.ok(new RecommendationResponse(
                samples.stream().filter(ContentSummary::pinned).toList(),
                samples,
                samples.reversed()
        ));
    }

    @GetMapping
    public ApiResponse<PageResponse<ContentSummary>> list(
            @RequestParam(required = false) String query,
            @RequestParam(required = false) List<String> tag,
            @RequestParam(required = false) ContentType type,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size
    ) {
        return ApiResponse.ok(new PageResponse<>(sampleContents(), page, size, sampleContents().size()));
    }

    @GetMapping("/{id}")
    public ApiResponse<ContentDetail> detail(@PathVariable UUID id) {
        return ApiResponse.ok(new ContentDetail(
                id,
                "用 Flutter 和 Spring AI 做一个会聊天的博客",
                ContentType.ARTICLE,
                ContentStatus.PUBLISHED,
                "这是一篇骨架示例内容，真实实现会从 PostgreSQL 读取。",
                """
                        # 用 Flutter 和 Spring AI 做一个会聊天的博客

                        这里展示 Markdown 内容。后续会支持目录、代码块、图文混排、评论和点赞。
                        """,
                List.of("Flutter", "Spring Boot", "AI"),
                Map.of("cover", "https://images.unsplash.com/photo-1515879218367-8466d910aaa4"),
                true,
                128,
                2048,
                12,
                Instant.now()
        ));
    }

    private List<ContentSummary> sampleContents() {
        return List.of(
                new ContentSummary(UUID.fromString("00000000-0000-0000-0000-000000000001"), "置顶：我的博客启动计划", ContentType.ARTICLE, "从工程骨架到 AI 助手。", "https://images.unsplash.com/photo-1515879218367-8466d910aaa4", true, 42, Instant.now()),
                new ContentSummary(UUID.fromString("00000000-0000-0000-0000-000000000002"), "一组生活照片", ContentType.IMAGE, "图片内容的画廊展示模式。", "https://images.unsplash.com/photo-1500530855697-b586d89ba3ee", false, 31, Instant.now()),
                new ContentSummary(UUID.fromString("00000000-0000-0000-0000-000000000003"), "一次短视频记录", ContentType.VIDEO, "视频内容的详情展示模式。", "https://images.unsplash.com/photo-1492691527719-9d1e07e534b4", false, 19, Instant.now())
        );
    }

    public record RecommendationResponse(
            List<ContentSummary> pinned,
            List<ContentSummary> latest,
            List<ContentSummary> mostLiked
    ) {
    }

    public record ContentSummary(
            UUID id,
            String title,
            ContentType type,
            String summary,
            String coverUrl,
            boolean pinned,
            long likeCount,
            Instant publishedAt
    ) {
    }

    public record ContentDetail(
            UUID id,
            String title,
            ContentType type,
            ContentStatus status,
            String summary,
            String bodyMarkdown,
            List<String> tags,
            Map<String, Object> media,
            boolean likedByCurrentUser,
            long likeCount,
            long viewCount,
            long commentCount,
            Instant publishedAt
    ) {
    }
}
