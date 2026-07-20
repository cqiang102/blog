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
import org.dromara.x.file.storage.core.FileStorageProperties;
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
                fileStorageService,
                storageProvisioner,
                "http://minio:9000",
                "https://blog.example.com/minio/",
                "blog-media",
                "uploads/");
    }

    @Test
    void uploadReturnsTheActualObjectKeyIncludingConfiguredBasePath() {
        byte[] bytes = new byte[] {1, 2, 3};
        UploadedFile file =
                new UploadedFile("photo.png", "image/png", bytes.length, () -> new ByteArrayInputStream(bytes));
        FileInfo fileInfo = new FileInfo();
        fileInfo.setPlatform("minio-1");
        fileInfo.setBasePath("uploads/");
        fileInfo.setPath("2026/06/14/");
        fileInfo.setFilename("photo.png");
        when(fileStorageService.of(any(InputStream.class), eq("photo.png"), eq("image/png"), eq(3L)))
                .thenReturn(uploadPretreatment);
        when(uploadPretreatment.upload()).thenReturn(fileInfo);

        StoredObject result = adapter.upload(file, "2026/06/14/", "photo.png", "image/png");

        assertThat(result).isEqualTo(new StoredObject("minio-1", "uploads/2026/06/14/photo.png"));
        verify(storageProvisioner).ensureReady();
        verify(uploadPretreatment).setPath("2026/06/14/");
        verify(uploadPretreatment).setSaveFilename("photo.png");
        verify(uploadPretreatment).setContentType("image/png");
    }

    @Test
    void rewritesInternalPresignedUrlToPublicEndpoint() {
        StoredObject object = new StoredObject("minio-1", "uploads/2026/06/photo.png");
        Instant expiresAt = Instant.parse("2026-06-21T00:00:00Z");
        String internalUrl = "http://minio:9000/blog-media/uploads/2026/06/photo.png" + "?X-Amz-Signature=abc123";
        when(fileStorageService.generatePresignedUrl(any(FileInfo.class), any(Date.class)))
                .thenReturn(internalUrl);

        String result = adapter.presignedUrl(object, expiresAt);

        assertThat(result)
                .isEqualTo("https://blog.example.com/minio/blog-media/uploads/2026/06/photo.png"
                        + "?X-Amz-Signature=abc123");
        ArgumentCaptor<FileInfo> fileInfoCaptor = ArgumentCaptor.forClass(FileInfo.class);
        ArgumentCaptor<Date> expiryCaptor = ArgumentCaptor.forClass(Date.class);
        verify(fileStorageService).generatePresignedUrl(fileInfoCaptor.capture(), expiryCaptor.capture());
        assertThat(fileInfoCaptor.getValue()).satisfies(fileInfo -> {
            assertThat(fileInfo.getPlatform()).isEqualTo("minio-1");
            assertThat(fileInfo.getBasePath()).isEqualTo("uploads/");
            assertThat(fileInfo.getPath()).isEqualTo("2026/06/");
            assertThat(fileInfo.getFilename()).isEqualTo("photo.png");
        });
        assertThat(expiryCaptor.getValue()).isEqualTo(Date.from(expiresAt));
    }

    @Test
    void normalizesConfiguredStorageUrlToPortablePath() {
        assertThat(adapter.normalizeForPersistence(
                        "https://blog.example.com/minio/blog-media/uploads/avatars/me.png?signature=abc"))
                .isEqualTo("/minio/blog-media/uploads/avatars/me.png");
        assertThat(adapter.normalizeForPersistence("https://cdn.example.com/blog-media/uploads/avatars/me.png"))
                .isEqualTo("https://cdn.example.com/blog-media/uploads/avatars/me.png");
    }

    @Test
    void presignsStableStoragePathUsingConfiguredPlatform() {
        Instant expiresAt = Instant.parse("2026-06-21T00:00:00Z");
        String internalUrl = "http://minio:9000/blog-media/uploads/avatars/me.png" + "?X-Amz-Signature=abc123";
        when(fileStorageService.getProperties()).thenReturn(new FileStorageProperties().setDefaultPlatform("minio-1"));
        when(fileStorageService.generatePresignedUrl(any(FileInfo.class), any(Date.class)))
                .thenReturn(internalUrl);

        assertThat(adapter.presignedUrl("/minio/blog-media/uploads/avatars/me.png", expiresAt))
                .contains(
                        "https://blog.example.com/minio/blog-media/uploads/avatars/me.png" + "?X-Amz-Signature=abc123");
    }

    @Test
    void deletesUsingBasePathAndRelativeObjectPath() {
        StoredObject object = new StoredObject("minio-1", "uploads/avatars/me.png");
        when(fileStorageService.delete(any(FileInfo.class))).thenReturn(true);

        adapter.delete(object);

        ArgumentCaptor<FileInfo> fileInfoCaptor = ArgumentCaptor.forClass(FileInfo.class);
        verify(fileStorageService).delete(fileInfoCaptor.capture());
        assertThat(fileInfoCaptor.getValue()).satisfies(fileInfo -> {
            assertThat(fileInfo.getBasePath()).isEqualTo("uploads/");
            assertThat(fileInfo.getPath()).isEqualTo("avatars/");
            assertThat(fileInfo.getFilename()).isEqualTo("me.png");
        });
    }
}
