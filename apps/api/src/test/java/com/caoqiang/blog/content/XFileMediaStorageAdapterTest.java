package com.caoqiang.blog.content;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
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

    private static final String PUBLIC_PLATFORM = "qiniu-public";
    private static final String PRIVATE_PLATFORM = "qiniu-private";
    private static final String PUBLIC_DOMAIN = "https://static.blog.lacia.cn/";
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
                fileStorageService,
                storageProvisioner,
                PUBLIC_PLATFORM,
                PRIVATE_PLATFORM,
                PUBLIC_DOMAIN,
                PRIVATE_DOMAIN,
                "lacia-public",
                "lacia-private",
                "uploads/");
    }

    @Test
    void uploadReturnsTheActualObjectKeyIncludingConfiguredBasePath() {
        byte[] bytes = new byte[] {1, 2, 3};
        UploadedFile file =
                new UploadedFile("photo.png", "image/png", bytes.length, () -> new ByteArrayInputStream(bytes));
        FileInfo fileInfo = new FileInfo();
        fileInfo.setPlatform(PUBLIC_PLATFORM);
        fileInfo.setBasePath("uploads/");
        fileInfo.setPath("2026/06/14/");
        fileInfo.setFilename("photo.png");
        when(fileStorageService.of(any(InputStream.class), eq("photo.png"), eq("image/png"), eq(3L)))
                .thenReturn(uploadPretreatment);
        when(uploadPretreatment.upload()).thenReturn(fileInfo);

        StoredObject result = adapter.upload(file, "2026/06/14/", "photo.png", "image/png");

        assertThat(result).isEqualTo(new StoredObject(PUBLIC_PLATFORM, "uploads/2026/06/14/photo.png"));
        verify(storageProvisioner).ensureReady();
        verify(uploadPretreatment).setPath("2026/06/14/");
        verify(uploadPretreatment).setSaveFilename("photo.png");
        verify(uploadPretreatment).setContentType("image/png");
        verify(uploadPretreatment, never()).setPlatform(any());
    }

    @Test
    void privateUploadRoutesToPrivatePlatform() {
        byte[] bytes = new byte[] {1, 2, 3};
        UploadedFile file =
                new UploadedFile("secret.pdf", "application/pdf", bytes.length, () -> new ByteArrayInputStream(bytes));
        FileInfo fileInfo = new FileInfo();
        fileInfo.setPlatform(PRIVATE_PLATFORM);
        fileInfo.setBasePath("uploads/");
        fileInfo.setPath("2026/06/14/");
        fileInfo.setFilename("secret.pdf");
        when(fileStorageService.of(any(InputStream.class), eq("secret.pdf"), eq("application/pdf"), eq(3L)))
                .thenReturn(uploadPretreatment);
        when(uploadPretreatment.upload()).thenReturn(fileInfo);

        StoredObject result = adapter.upload(file, "2026/06/14/", "secret.pdf", "application/pdf", true);

        assertThat(result).isEqualTo(new StoredObject(PRIVATE_PLATFORM, "uploads/2026/06/14/secret.pdf"));
        verify(uploadPretreatment).setPlatform(PRIVATE_PLATFORM);
    }

    @Test
    void publicUrlReturnsCdnLinkForPublicPlatform() {
        StoredObject object = new StoredObject(PUBLIC_PLATFORM, "uploads/2026/06/photo.png");

        assertThat(adapter.publicUrl(object))
                .contains("https://static.blog.lacia.cn/uploads/2026/06/photo.png");
    }

    @Test
    void publicUrlIsEmptyForPrivatePlatform() {
        StoredObject object = new StoredObject(PRIVATE_PLATFORM, "uploads/2026/06/secret.pdf");

        assertThat(adapter.publicUrl(object)).isEmpty();
    }

    @Test
    void presignedUrlReturnsSignedUrlAsIs() {
        StoredObject object = new StoredObject(PUBLIC_PLATFORM, "uploads/2026/06/photo.png");
        Instant expiresAt = Instant.parse("2026-06-21T00:00:00Z");
        String signedUrl = "https://static.blog.lacia.cn/uploads/2026/06/photo.png?e=1782000000&token=abc";
        when(fileStorageService.generatePresignedUrl(any(FileInfo.class), any(Date.class)))
                .thenReturn(signedUrl);

        String result = adapter.presignedUrl(object, expiresAt);

        assertThat(result).isEqualTo(signedUrl);
        ArgumentCaptor<FileInfo> fileInfoCaptor = ArgumentCaptor.forClass(FileInfo.class);
        verify(fileStorageService).generatePresignedUrl(fileInfoCaptor.capture(), any(Date.class));
        assertThat(fileInfoCaptor.getValue()).satisfies(fileInfo -> {
            assertThat(fileInfo.getPlatform()).isEqualTo(PUBLIC_PLATFORM);
            assertThat(fileInfo.getBasePath()).isEqualTo("uploads/");
            assertThat(fileInfo.getPath()).isEqualTo("2026/06/");
            assertThat(fileInfo.getFilename()).isEqualTo("photo.png");
        });
    }

    @Test
    void publicCdnUrlIsReturnedDirectlyWithoutSigning() {
        Instant expiresAt = Instant.parse("2026-06-21T00:00:00Z");

        assertThat(adapter.presignedUrl("https://static.blog.lacia.cn/uploads/avatars/me.png?sig=abc", expiresAt))
                .contains("https://static.blog.lacia.cn/uploads/avatars/me.png");
        verify(fileStorageService, never()).generatePresignedUrl(any(), any());
    }

    @Test
    void privateUrlIsSignedWithPrivatePlatform() {
        Instant expiresAt = Instant.parse("2026-06-21T00:00:00Z");
        String signedUrl = "https://file.lacia.cn/uploads/secret.pdf?e=1782000000&token=abc";
        when(fileStorageService.generatePresignedUrl(any(FileInfo.class), any(Date.class)))
                .thenReturn(signedUrl);

        assertThat(adapter.presignedUrl("https://file.lacia.cn/uploads/secret.pdf", expiresAt))
                .hasValue("https://file.lacia.cn/uploads/secret.pdf?e=1782000000&token=abc");
        ArgumentCaptor<FileInfo> fileInfoCaptor = ArgumentCaptor.forClass(FileInfo.class);
        verify(fileStorageService).generatePresignedUrl(fileInfoCaptor.capture(), any(Date.class));
        assertThat(fileInfoCaptor.getValue().getPlatform()).isEqualTo(PRIVATE_PLATFORM);
    }

    @Test
    void normalizesCdnAndLegacyUrlsToPortablePath() {
        assertThat(adapter.normalizeForPersistence(
                        "https://static.blog.lacia.cn/uploads/avatars/me.png?signature=abc"))
                .isEqualTo("https://static.blog.lacia.cn/uploads/avatars/me.png");
        assertThat(adapter.normalizeForPersistence("/minio/lacia-public/uploads/avatars/me.png"))
                .isEqualTo("https://static.blog.lacia.cn/uploads/avatars/me.png");
        assertThat(adapter.normalizeForPersistence("https://file.lacia.cn/uploads/secret.pdf?e=1"))
                .isEqualTo("https://file.lacia.cn/uploads/secret.pdf?e=1");
        assertThat(adapter.normalizeForPersistence("https://cdn.example.com/other.png"))
                .isEqualTo("https://cdn.example.com/other.png");
    }

    @Test
    void deletesUsingBasePathAndRelativeObjectPath() {
        StoredObject object = new StoredObject(PUBLIC_PLATFORM, "uploads/avatars/me.png");
        when(fileStorageService.delete(any(FileInfo.class))).thenReturn(true);

        adapter.delete(object);

        ArgumentCaptor<FileInfo> fileInfoCaptor = ArgumentCaptor.forClass(FileInfo.class);
        verify(fileStorageService).delete(fileInfoCaptor.capture());
        assertThat(fileInfoCaptor.getValue()).satisfies(fileInfo -> {
            assertThat(fileInfo.getPlatform()).isEqualTo(PUBLIC_PLATFORM);
            assertThat(fileInfo.getBasePath()).isEqualTo("uploads/");
            assertThat(fileInfo.getPath()).isEqualTo("avatars/");
            assertThat(fileInfo.getFilename()).isEqualTo("me.png");
        });
    }
}
