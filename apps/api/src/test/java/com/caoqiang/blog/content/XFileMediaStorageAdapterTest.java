package com.caoqiang.blog.content;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.content.application.port.MediaStorage.StoredObject;
import com.caoqiang.blog.content.application.port.MediaStorageProvisioner;
import com.caoqiang.blog.content.infrastructure.storage.XFileMediaStorageAdapter;
import com.caoqiang.blog.shared.model.UploadedFile;
import java.io.ByteArrayInputStream;
import java.io.InputStream;
import java.time.Instant;
import java.util.Date;
import org.dromara.x.file.storage.core.FileInfo;
import org.dromara.x.file.storage.core.FileStorageService;
import org.dromara.x.file.storage.core.upload.UploadPretreatment;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Answers;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class XFileMediaStorageAdapterTest {

    private static final String PRIVATE_PLATFORM = "qiniu-private";
    private static final String PRIVATE_DOMAIN = "https://file.lacia.cn/";

    @Mock
    private FileStorageService fileStorageService;

    @Mock
    private MediaStorageProvisioner storageProvisioner;

    @Mock(answer = Answers.RETURNS_SELF)
    private UploadPretreatment uploadPretreatment;

    private XFileMediaStorageAdapter adapter;

    @BeforeEach
    void setUp() {
        adapter = new XFileMediaStorageAdapter(
                fileStorageService, storageProvisioner, PRIVATE_PLATFORM, PRIVATE_DOMAIN, "lacia-private", "uploads/");
    }

    @Test
    void uploadReturnsTheActualObjectKeyIncludingConfiguredBasePath() {
        byte[] bytes = new byte[] {1, 2, 3};
        UploadedFile file =
                new UploadedFile("photo.png", "image/png", bytes.length, () -> new ByteArrayInputStream(bytes));
        FileInfo fileInfo = new FileInfo();
        fileInfo.setPlatform(PRIVATE_PLATFORM);
        fileInfo.setBasePath("uploads/");
        fileInfo.setPath("2026/06/14/");
        fileInfo.setFilename("photo.png");
        when(fileStorageService.of(any(InputStream.class), eq("photo.png"), eq("image/png"), eq(3L)))
                .thenReturn(uploadPretreatment);
        when(uploadPretreatment.upload()).thenReturn(fileInfo);

        StoredObject result = adapter.upload(file, "2026/06/14/", "photo.png", "image/png");

        assertThat(result).isEqualTo(new StoredObject(PRIVATE_PLATFORM, "uploads/2026/06/14/photo.png"));
        verify(storageProvisioner).ensureReady();
        verify(uploadPretreatment).setPath("2026/06/14/");
        verify(uploadPretreatment).setSaveFilename("photo.png");
        verify(uploadPretreatment).setContentType("image/png");
    }

    @Test
    void presignedUrlReturnsSignedUrlAsIs() {
        StoredObject object = new StoredObject(PRIVATE_PLATFORM, "uploads/2026/06/photo.png");
        Instant expiresAt = Instant.parse("2026-06-21T00:00:00Z");
        String signedUrl = "https://file.lacia.cn/uploads/2026/06/photo.png?e=1782000000&token=abc";
        when(fileStorageService.generatePresignedUrl(any(FileInfo.class), any(Date.class)))
                .thenReturn(signedUrl);

        String result = adapter.presignedUrl(object, expiresAt);

        assertThat(result).isEqualTo(signedUrl);
        ArgumentCaptor<FileInfo> fileInfoCaptor = ArgumentCaptor.forClass(FileInfo.class);
        verify(fileStorageService).generatePresignedUrl(fileInfoCaptor.capture(), any(Date.class));
        assertThat(fileInfoCaptor.getValue()).satisfies(fileInfo -> {
            assertThat(fileInfo.getPlatform()).isEqualTo(PRIVATE_PLATFORM);
            assertThat(fileInfo.getBasePath()).isEqualTo("uploads/");
            assertThat(fileInfo.getPath()).isEqualTo("2026/06/");
            assertThat(fileInfo.getFilename()).isEqualTo("photo.png");
        });
    }

    @Test
    void presignsUrlByKeyWithPrivatePlatform() {
        Instant expiresAt = Instant.parse("2026-06-21T00:00:00Z");
        String signedUrl = "https://file.lacia.cn/uploads/avatars/me.png?e=1782000000&token=abc";
        when(fileStorageService.generatePresignedUrl(any(FileInfo.class), any(Date.class)))
                .thenReturn(signedUrl);

        assertThat(adapter.presignedUrlByKey("uploads/avatars/me.png", expiresAt))
                .isEqualTo(signedUrl);
        ArgumentCaptor<FileInfo> fileInfoCaptor = ArgumentCaptor.forClass(FileInfo.class);
        verify(fileStorageService).generatePresignedUrl(fileInfoCaptor.capture(), any(Date.class));
        assertThat(fileInfoCaptor.getValue().getPlatform()).isEqualTo(PRIVATE_PLATFORM);
    }

    @Test
    void portablePathIsStableStorageApiPath() {
        assertThat(adapter.portablePath("uploads/2026/06/photo.png"))
                .isEqualTo("/api/v1/storage/file?key=uploads%2F2026%2F06%2Fphoto.png");
    }

    @Test
    void presignsStorageApiPathAndLegacyMinioPath() {
        Instant expiresAt = Instant.parse("2026-06-21T00:00:00Z");
        String signedUrl = "https://file.lacia.cn/uploads/2026/06/photo.png?e=1782000000&token=abc";
        when(fileStorageService.generatePresignedUrl(any(FileInfo.class), any(Date.class)))
                .thenReturn(signedUrl);

        assertThat(adapter.presignedUrl("/api/v1/storage/file?key=uploads%2F2026%2F06%2Fphoto.png", expiresAt))
                .hasValue(signedUrl);
        assertThat(adapter.presignedUrl("https://file.lacia.cn/uploads/2026/06/photo.png", expiresAt))
                .hasValue(signedUrl);
        assertThat(adapter.presignedUrl("/minio/lacia-private/uploads/2026/06/photo.png", expiresAt))
                .hasValue(signedUrl);
    }

    @Test
    void normalizesStorageUrlsToPortablePath() {
        assertThat(adapter.normalizeForPersistence("https://file.lacia.cn/uploads/avatars/me.png?e=1"))
                .isEqualTo("/api/v1/storage/file?key=uploads%2Favatars%2Fme.png");
        assertThat(adapter.normalizeForPersistence("/minio/lacia-private/uploads/avatars/me.png"))
                .isEqualTo("/api/v1/storage/file?key=uploads%2Favatars%2Fme.png");
        assertThat(adapter.normalizeForPersistence("https://cdn.example.com/other.png"))
                .isEqualTo("https://cdn.example.com/other.png");
    }

    @Test
    void deletesUsingBasePathAndRelativeObjectPath() {
        StoredObject object = new StoredObject(PRIVATE_PLATFORM, "uploads/avatars/me.png");
        when(fileStorageService.delete(any(FileInfo.class))).thenReturn(true);

        adapter.delete(object);

        ArgumentCaptor<FileInfo> fileInfoCaptor = ArgumentCaptor.forClass(FileInfo.class);
        verify(fileStorageService).delete(fileInfoCaptor.capture());
        assertThat(fileInfoCaptor.getValue()).satisfies(fileInfo -> {
            assertThat(fileInfo.getPlatform()).isEqualTo(PRIVATE_PLATFORM);
            assertThat(fileInfo.getBasePath()).isEqualTo("uploads/");
            assertThat(fileInfo.getPath()).isEqualTo("avatars/");
            assertThat(fileInfo.getFilename()).isEqualTo("me.png");
        });
    }
}
