package com.caoqiang.blog.content;

import com.caoqiang.blog.auth.AuthenticatedUser;
import com.caoqiang.blog.common.ApiResponse;
import com.caoqiang.blog.common.PageResponse;
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

@RestController
@RequestMapping("/api/v1/contents")
public class ContentController {

    private final ContentService contentService;
    private final TagRepository tagRepository;

    public ContentController(ContentService contentService, TagRepository tagRepository) {
        this.contentService = contentService;
        this.tagRepository = tagRepository;
    }

    @GetMapping("/recommendations")
    public ApiResponse<RecommendationResponse> recommendations() {
        return ApiResponse.ok(contentService.recommendations());
    }

    @GetMapping
    public ApiResponse<PageResponse<ContentSummaryResponse>> list(
            @RequestParam(required = false) String query,
            @RequestParam(required = false) List<String> tag,
            @RequestParam(required = false) ContentType type,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant from,
            @RequestParam(required = false) @DateTimeFormat(iso = DateTimeFormat.ISO.DATE_TIME) Instant to,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "10") int size
    ) {
        return ApiResponse.ok(contentService.list(query, tag, type, from, to, page, size));
    }

    @GetMapping("/{id}")
    public ApiResponse<ContentDetailResponse> detail(
            @PathVariable UUID id,
            @AuthenticationPrincipal AuthenticatedUser currentUser
    ) {
        return ApiResponse.ok(contentService.detail(id, currentUser));
    }

    @GetMapping("/tags")
    public ApiResponse<List<TagResponse>> tags() {
        return ApiResponse.ok(tagRepository.findAll().stream()
                .map(tag -> new TagResponse(tag.getId(), tag.getName(), tag.getSlug(), tag.getDescription()))
                .toList());
    }
}
