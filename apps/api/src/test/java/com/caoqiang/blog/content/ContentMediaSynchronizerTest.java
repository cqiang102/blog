package com.caoqiang.blog.content;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.content.application.service.ContentMediaSynchronizer;
import com.caoqiang.blog.content.domain.model.Content;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.model.MediaAsset;
import com.caoqiang.blog.content.domain.model.MediaAssetType;
import com.caoqiang.blog.content.domain.model.MediaReference;
import com.caoqiang.blog.content.domain.repository.MediaAssetRepository;
import com.caoqiang.blog.shared.exception.BusinessException;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class ContentMediaSynchronizerTest {

    @Mock
    private MediaAssetRepository mediaAssetRepository;

    private ContentMediaSynchronizer synchronizer;
    private Content content;

    @BeforeEach
    void setUp() {
        synchronizer = new ContentMediaSynchronizer(mediaAssetRepository);
        content = content("article", ContentType.ARTICLE);
    }

    @Test
    void keepsRequestOrderAndDeduplicatesReferences() {
        MediaAsset first = managedMedia(null, "first.png");
        MediaAsset second = managedMedia(null, "second.png");
        when(mediaAssetRepository.findById(first.getId())).thenReturn(Optional.of(first));
        when(mediaAssetRepository.findById(second.getId())).thenReturn(Optional.of(second));
        when(mediaAssetRepository.save(any(MediaAsset.class))).thenAnswer(invocation -> invocation.getArgument(0));

        List<MediaAsset> result = synchronizer.synchronize(
                content,
                List.of(
                        MediaReference.filePath(second.getId()),
                        MediaReference.filePath(first.getId()),
                        MediaReference.filePath(second.getId())),
                ContentType.ARTICLE);

        assertThat(result).containsExactly(second, first);
        assertThat(content.getMediaAssets()).containsExactly(second, first);
        assertThat(second.getContent()).isSameAs(content);
    }

    @Test
    void rejectsMediaOwnedByAnotherContent() {
        Content other = content("other", ContentType.ARTICLE);
        MediaAsset owned = managedMedia(other, "owned.png");
        when(mediaAssetRepository.findById(owned.getId())).thenReturn(Optional.of(owned));

        assertThatThrownBy(() -> synchronizer.synchronize(
                        content, List.of(MediaReference.filePath(owned.getId())), ContentType.ARTICLE))
                .isInstanceOf(BusinessException.class)
                .hasMessageContaining("已关联到其他内容");

        verify(mediaAssetRepository, never()).save(owned);
    }

    @Test
    void deletesRemovedExternalMediaAndDetachesManagedMedia() {
        MediaAsset external = new MediaAsset(
                content,
                MediaAssetType.IMAGE,
                MediaAsset.EXTERNAL_BUCKET,
                "external/key",
                "https://cdn.example.com/image.png",
                null,
                null,
                null,
                null,
                null,
                null);
        MediaAsset managed = managedMedia(content, "managed.png");
        content.getMediaAssets().addAll(List.of(external, managed));
        when(mediaAssetRepository.save(any(MediaAsset.class))).thenAnswer(invocation -> invocation.getArgument(0));

        synchronizer.synchronize(content, List.of(), ContentType.ARTICLE);

        verify(mediaAssetRepository).delete(external);
        verify(mediaAssetRepository).save(managed);
        assertThat(managed.getContent()).isNull();
        assertThat(content.getMediaAssets()).isEmpty();
    }

    @Test
    void selectsExplicitCoverAndFallsBackToFirstMedia() {
        MediaAsset first = managedMedia(content, "first.png");
        MediaAsset second = managedMedia(content, "second.png");
        List<MediaAsset> media = List.of(first, second);

        assertThat(synchronizer.selectCover(media, MediaReference.filePath(second.getId())))
                .isSameAs(second);
        assertThat(synchronizer.selectCover(media, "unknown-reference")).isSameAs(first);
        assertThat(synchronizer.selectCover(List.of(), null)).isNull();
    }

    private Content content(String slug, ContentType type) {
        return new Content(slug, slug, type, ContentStatus.DRAFT, null, null, false, null, Set.of());
    }

    private MediaAsset managedMedia(Content owner, String name) {
        return new MediaAsset(
                owner,
                MediaAssetType.IMAGE,
                "blog-media",
                "uploads/" + name,
                null,
                name,
                "image/png",
                42L,
                100,
                100,
                null);
    }
}
