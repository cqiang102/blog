package com.caoqiang.blog.content;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.content.application.service.MediaAdminService;
import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.repository.MediaAssetRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Date;
import java.util.Optional;
import org.dromara.x.file.storage.core.FileInfo;
import org.dromara.x.file.storage.core.FileStorageService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class MediaAdminServiceTest {

    @Mock
    private MediaAssetRepository mediaAssetRepository;

    @Mock
    private ContentRepository contentRepository;

    @Mock
    private FileStorageService fileStorageService;

    @Test
    void rewritesInternalMinioPresignedUrlToThePublicProxy() {
        MediaAsset asset = new MediaAsset(
                null,
                MediaAssetType.IMAGE,
                "minio-1",
                "uploads/2026/06/photo.png",
                "http://minio:9000/blog-media/uploads/2026/06/photo.png",
                "photo.png",
                "image/png",
                128L,
                null,
                null,
                null
        );
        MediaAdminService service = new MediaAdminService(
                mediaAssetRepository,
                contentRepository,
                fileStorageService,
                Clock.fixed(Instant.parse("2026-06-14T00:00:00Z"), ZoneOffset.UTC),
                "http://minio:9000",
                "https://blog.example.com/minio/",
                "blog-media",
                "uploads/"
        );
        String internalUrl = "http://minio:9000/blog-media/uploads/2026/06/photo.png"
                + "?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=abc123";

        when(mediaAssetRepository.findById(asset.getId())).thenReturn(Optional.of(asset));
        when(fileStorageService.generatePresignedUrl(any(FileInfo.class), any(Date.class)))
                .thenReturn(internalUrl);

        String result = service.getPresignedUrl(asset.getId());

        assertThat(result).isEqualTo(
                "https://blog.example.com/minio/blog-media/uploads/2026/06/photo.png"
                        + "?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=abc123"
        );
    }

    @Test
    void normalizesConfiguredStorageUrlsForPersistence() {
        MediaAdminService service = new MediaAdminService(
                mediaAssetRepository,
                contentRepository,
                fileStorageService,
                Clock.fixed(Instant.parse("2026-06-14T00:00:00Z"), ZoneOffset.UTC),
                "http://minio:9000",
                "https://blog.example.com/minio",
                "blog-media",
                "uploads/"
        );

        assertThat(service.normalizeStorageUrlForPersistence(
                "https://blog.example.com/minio/blog-media/uploads/avatars/me.png?X-Amz-Signature=abc"
        )).isEqualTo("/minio/blog-media/uploads/avatars/me.png");
        assertThat(service.normalizeStorageUrlForPersistence(
                "https://cdn.example.com/blog-media/uploads/avatars/me.png"
        )).isEqualTo("https://cdn.example.com/blog-media/uploads/avatars/me.png");
    }

    @Test
    void resolvesPortableStoragePathToPublicPresignedUrl() {
        MediaAdminService service = new MediaAdminService(
                mediaAssetRepository,
                contentRepository,
                fileStorageService,
                Clock.fixed(Instant.parse("2026-06-14T00:00:00Z"), ZoneOffset.UTC),
                "http://minio:9000",
                "https://blog.example.com/minio",
                "blog-media",
                "uploads/"
        );
        String internalUrl = "http://minio:9000/blog-media/uploads/avatars/me.png"
                + "?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=abc123";

        when(fileStorageService.generatePresignedUrl(any(FileInfo.class), any(Date.class)))
                .thenReturn(internalUrl);

        String result = service.resolveUrl("/minio/blog-media/uploads/avatars/me.png");

        assertThat(result).isEqualTo(
                "https://blog.example.com/minio/blog-media/uploads/avatars/me.png"
                        + "?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Signature=abc123"
        );
    }
}
