package com.caoqiang.blog.content;

import java.util.List;

public record RecommendationResponse(
        List<ContentSummaryResponse> pinned,
        List<ContentSummaryResponse> latest,
        List<ContentSummaryResponse> mostLiked
) {
}
