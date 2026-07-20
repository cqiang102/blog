package com.caoqiang.blog.content;

import static org.assertj.core.api.Assertions.assertThat;

import com.caoqiang.blog.content.application.dto.AdminContentResponse;
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import java.util.Set;
import org.junit.jupiter.api.Test;

class AdminContentResponseTest {

    @Test
    void usesStableSameOriginMediaPathsWithoutStorageIo() {
        Content content = new Content(
                "Title", "title", ContentType.ARTICLE, ContentStatus.DRAFT, "Summary", "Body", false, null, Set.of());
        MediaAsset cover = new MediaAsset(
                content,
                MediaAssetType.IMAGE,
                "minio-1",
                "uploads/cover.png",
                null,
                "cover.png",
                "image/png",
                100L,
                null,
                null,
                null);
        content.getMediaAssets().add(cover);
        content.setCoverMedia(cover);

        AdminContentResponse response = AdminContentResponse.from(content);

        assertThat(response.coverUrl()).isEqualTo("/api/v1/media-assets/" + cover.getId() + "/file");
        assertThat(response.mediaUrls()).containsExactly(response.coverUrl());
    }
}
