package com.caoqiang.blog.content;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.content.application.port.MediaStorage.StoredObject;
import com.caoqiang.blog.content.application.service.MediaAssetWriter;
import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.repository.MediaAssetRepository;
import com.caoqiang.blog.shared.exception.BusinessException;
import java.util.Optional;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class MediaAssetWriterTest {

    @Mock
    private MediaAssetRepository mediaAssetRepository;

    @Mock
    private ContentRepository contentRepository;

    private MediaAssetWriter writer;

    @BeforeEach
    void setUp() {
        writer = new MediaAssetWriter(mediaAssetRepository, contentRepository);
    }

    @Test
    void persistsUploadedMetadataWithStableProxyUrl() {
        StoredObject storedObject = new StoredObject("minio-1", "uploads/2026/07/photo.png");
        when(mediaAssetRepository.save(any(MediaAsset.class))).thenAnswer(invocation -> invocation.getArgument(0));

        var response = writer.createUploaded(null, MediaAssetType.IMAGE, storedObject, "photo.png", "image/png", 128L);

        assertThat(response.bucket()).isEqualTo("minio-1");
        assertThat(response.objectKey()).isEqualTo(storedObject.objectKey());
        assertThat(response.publicUrl()).isEqualTo("/api/v1/media-assets/" + response.id() + "/file");
    }

    @Test
    void revalidatesContentInsideTheMetadataTransaction() {
        UUID contentId = UUID.randomUUID();
        when(contentRepository.findById(contentId)).thenReturn(Optional.empty());

        assertThatThrownBy(() -> writer.createUploaded(
                        contentId,
                        MediaAssetType.IMAGE,
                        new StoredObject("minio-1", "uploads/photo.png"),
                        "photo.png",
                        "image/png",
                        128L))
                .isInstanceOf(BusinessException.class)
                .hasMessage("内容不存在");

        verify(mediaAssetRepository, never()).save(any());
    }
}
