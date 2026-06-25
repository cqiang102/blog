package com.caoqiang.blog.content.domain.model;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.Test;

class MediaReferenceTest {

    @Test
    void parsesRelativeAndAbsoluteMediaReferences() {
        UUID id = UUID.randomUUID();
        String path = MediaReference.filePath(id);

        assertThat(MediaReference.mediaId(path)).contains(id);
        assertThat(MediaReference.mediaId("https://blog.example.com" + path))
                .contains(id);
        assertThat(MediaReference.mediaId("https://cdn.example.com/a.png"))
                .isEmpty();
    }

    @Test
    void replacesPrivateStorageUrlsInMarkdown() {
        MediaAsset media = new MediaAsset(
                null,
                MediaAssetType.IMAGE,
                "minio",
                "2026/06/photo.png",
                "http://localhost:9000/uploads/2026/06/photo.png",
                "photo.png",
                "image/png",
                10L,
                100,
                80,
                null
        );
        UUID id = media.getId();

        String markdown = "![图片](http://localhost:9000/uploads/2026/06/photo.png)";

        assertThat(MediaReference.normalizeMarkdown(markdown, List.of(media)))
                .isEqualTo("![图片](" + MediaReference.filePath(id) + ")");
    }

    @Test
    void replacesStableMinioPathsInMarkdown() {
        MediaAsset media = new MediaAsset(
                null,
                MediaAssetType.IMAGE,
                "blog-media",
                "uploads/2026/06/photo.png",
                "/api/v1/media-assets/old/file",
                "photo.png",
                "image/png",
                10L,
                100,
                80,
                null
        );

        String markdown = "![图片](/minio/blog-media/uploads/2026/06/photo.png)";

        assertThat(MediaReference.normalizeMarkdown(markdown, List.of(media)))
                .isEqualTo("![图片](" + MediaReference.filePath(media.getId()) + ")");
    }
}
