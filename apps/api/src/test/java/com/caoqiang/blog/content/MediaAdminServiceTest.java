package com.caoqiang.blog.content;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.content.application.port.MediaStorage;
import com.caoqiang.blog.content.application.port.MediaStorage.StoredObject;
import com.caoqiang.blog.content.application.service.MediaAdminService;
import com.caoqiang.blog.content.application.service.MediaAssetWriter;
import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.repository.MediaAssetRepository;
import com.caoqiang.blog.shared.model.UploadedFile;
import java.io.ByteArrayInputStream;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.Optional;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

@ExtendWith(MockitoExtension.class)
class MediaAdminServiceTest {

    private static final Instant NOW = Instant.parse("2026-06-14T00:00:00Z");

    @Mock
    private MediaAssetRepository mediaAssetRepository;

    @Mock
    private ContentRepository contentRepository;

    @Mock
    private MediaStorage mediaStorage;

    @Mock
    private MediaAssetWriter mediaAssetWriter;

    private MediaAdminService service;

    @BeforeEach
    void setUp() {
        service = new MediaAdminService(
                mediaAssetRepository,
                contentRepository,
                mediaStorage,
                mediaAssetWriter,
                Clock.fixed(NOW, ZoneOffset.UTC));
    }

    @AfterEach
    void clearTransactionSynchronization() {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }

    @Test
    void resolvesManagedMediaThroughStoragePort() {
        MediaAsset asset = managedAsset();
        StoredObject storedObject = new StoredObject(asset.getBucket(), asset.getObjectKey());
        String signedUrl = "https://blog.example.com/minio/blog-media/uploads/2026/06/photo.png?signed";
        when(mediaAssetRepository.findById(asset.getId())).thenReturn(Optional.of(asset));
        when(mediaStorage.presignedUrl(storedObject, NOW.plusSeconds(7 * 24 * 60 * 60)))
                .thenReturn(signedUrl);

        assertThat(service.getPresignedUrl(asset.getId())).isEqualTo(signedUrl);
    }

    @Test
    void delegatesStorageUrlNormalizationToThePort() {
        String source = "https://blog.example.com/minio/blog-media/uploads/avatars/me.png?signature=abc";
        String portable = "/minio/blog-media/uploads/avatars/me.png";
        when(mediaStorage.normalizeForPersistence(source)).thenReturn(portable);

        assertThat(service.normalizeStorageUrlForPersistence(source)).isEqualTo(portable);
    }

    @Test
    void compensatesImmediatelyWhenMediaRecordCreationFailsWithoutTransaction() {
        StoredObject storedObject = new StoredObject("qiniu-private", "uploads/2026/06/photo.png");
        UploadedFile file = imageFile();
        when(mediaStorage.upload(file, "2026/06/14/", "photo.png", "image/png"))
                .thenReturn(storedObject);
        when(mediaAssetWriter.createUploaded(
                        null, MediaAssetType.IMAGE, storedObject, "photo.png", "image/png", file.size()))
                .thenThrow(new IllegalStateException("database unavailable"));

        assertThatThrownBy(() -> service.upload(null, MediaAssetType.IMAGE, file))
                .isInstanceOf(IllegalStateException.class)
                .hasMessage("database unavailable");

        verify(mediaStorage).delete(storedObject);
    }

    @Test
    void keepsUploadedObjectAfterMediaRecordIsCommitted() {
        StoredObject storedObject = new StoredObject("qiniu-private", "uploads/2026/06/photo.png");
        UploadedFile file = imageFile();
        MediaAsset asset = managedAsset();
        when(mediaStorage.upload(file, "2026/06/14/", "photo.png", "image/png"))
                .thenReturn(storedObject);
        when(mediaAssetWriter.createUploaded(
                        null, MediaAssetType.IMAGE, storedObject, "photo.png", "image/png", file.size()))
                .thenReturn(com.caoqiang.blog.content.application.dto.AdminMediaResponse.from(asset));

        service.upload(null, MediaAssetType.IMAGE, file);

        verify(mediaAssetWriter)
                .createUploaded(null, MediaAssetType.IMAGE, storedObject, "photo.png", "image/png", file.size());
        verify(mediaStorage, never()).delete(storedObject);
    }

    @Test
    void deletesStoredObjectOnlyAfterDatabaseCommit() {
        MediaAsset asset = managedAsset();
        StoredObject storedObject = new StoredObject(asset.getBucket(), asset.getObjectKey());
        when(mediaAssetRepository.findById(asset.getId())).thenReturn(Optional.of(asset));
        TransactionSynchronizationManager.initSynchronization();

        service.delete(asset.getId());

        verify(mediaAssetRepository).delete(asset);
        verify(mediaStorage, never()).delete(storedObject);

        TransactionSynchronizationManager.getSynchronizations().getFirst().afterCommit();

        verify(mediaStorage).delete(storedObject);
    }

    @Test
    void keepsStoredObjectWhenDatabaseDeletionRollsBack() {
        MediaAsset asset = managedAsset();
        StoredObject storedObject = new StoredObject(asset.getBucket(), asset.getObjectKey());
        when(mediaAssetRepository.findById(asset.getId())).thenReturn(Optional.of(asset));
        TransactionSynchronizationManager.initSynchronization();

        service.delete(asset.getId());
        TransactionSynchronizationManager.getSynchronizations()
                .getFirst()
                .afterCompletion(TransactionSynchronization.STATUS_ROLLED_BACK);

        verify(mediaAssetRepository).delete(asset);
        verify(mediaStorage, never()).delete(storedObject);
    }

    @Test
    void rejectsDeletionWhenMediaIsReferencedInContentBody() {
        MediaAsset asset = managedAsset();
        com.caoqiang.blog.content.domain.model.Content content = new com.caoqiang.blog.content.domain.model.Content(
                "文章",
                "slug",
                com.caoqiang.blog.content.domain.model.ContentType.ARTICLE,
                com.caoqiang.blog.content.domain.model.ContentStatus.DRAFT,
                null,
                "正文 ![img](" + com.caoqiang.blog.content.domain.model.MediaReference.filePath(asset.getId()) + ")",
                false,
                null,
                java.util.Set.of());
        asset.assignTo(content);
        when(mediaAssetRepository.findById(asset.getId())).thenReturn(Optional.of(asset));

        assertThatThrownBy(() -> service.delete(asset.getId()))
                .isInstanceOf(com.caoqiang.blog.shared.exception.BusinessException.class)
                .satisfies(e -> assertThat(((com.caoqiang.blog.shared.exception.BusinessException) e).status())
                        .isEqualTo(org.springframework.http.HttpStatus.CONFLICT));

        verify(mediaAssetRepository, never()).delete(asset);
    }

    @Test
    void presignsArbitraryObjectKeyThroughPort() {
        String signedUrl = "https://file.lacia.cn/uploads/2026/06/avatar.png?e=1782000000";
        when(mediaStorage.presignedUrlByKey("uploads/2026/06/avatar.png", NOW.plusSeconds(7 * 24 * 60 * 60)))
                .thenReturn(signedUrl);

        assertThat(service.presignedUrlForKey("uploads/2026/06/avatar.png")).isEqualTo(signedUrl);
    }

    private MediaAsset managedAsset() {
        return new MediaAsset(
                null,
                MediaAssetType.IMAGE,
                "qiniu-private",
                "uploads/2026/06/photo.png",
                "/api/v1/media-assets/file",
                "photo.png",
                "image/png",
                128L,
                null,
                null,
                null);
    }

    private UploadedFile imageFile() {
        byte[] bytes = new byte[] {(byte) 0x89, 0x50, 0x4E, 0x47};
        return new UploadedFile("photo.png", "image/png", bytes.length, () -> new ByteArrayInputStream(bytes));
    }
}
