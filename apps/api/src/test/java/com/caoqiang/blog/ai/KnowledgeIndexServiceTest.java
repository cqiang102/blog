package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeChunk;
import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeDoc;
import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeSourceType;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeDocRepository;
import com.caoqiang.blog.ai.knowledge.application.service.EmbeddingService;
import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeIndexService;
import com.caoqiang.blog.content.application.api.ContentKnowledgeService;
import com.caoqiang.blog.content.application.api.ContentKnowledgeSource;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.mockito.ArgumentCaptor;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class KnowledgeIndexServiceTest {

    @Mock
    private KnowledgeDocRepository knowledgeDocRepository;

    @Mock
    private KnowledgeChunkRepository knowledgeChunkRepository;

    @Mock
    private EmbeddingService embeddingService;

    @Mock
    private ContentKnowledgeService contentKnowledgeService;

    private KnowledgeIndexService knowledgeIndexService;

    @BeforeEach
    void setUp() {
        knowledgeIndexService = new KnowledgeIndexService(
                knowledgeDocRepository,
                knowledgeChunkRepository,
                embeddingService,
                contentKnowledgeService
        );
    }

    @Test
    void splitTextIntoChunks() {
        String text = "第一段内容。\n\n第二段内容。\n\n第三段内容。";

        List<String> chunks = knowledgeIndexService.splitText(text);

        // Short paragraphs are combined into a single chunk since total < CHUNK_SIZE (500)
        assertThat(chunks).hasSize(1);
        assertThat(chunks.get(0)).contains("第一段内容。");
        assertThat(chunks.get(0)).contains("第二段内容。");
        assertThat(chunks.get(0)).contains("第三段内容。");
    }

    @Test
    void handleEmptyText() {
        List<String> chunks = knowledgeIndexService.splitText("");
        assertThat(chunks).isEmpty();

        chunks = knowledgeIndexService.splitText(null);
        assertThat(chunks).isEmpty();
    }

    @Test
    void splitLongText() {
        StringBuilder longText = new StringBuilder();
        for (int i = 0; i < 100; i++) {
            longText.append("这是第").append(i).append("段内容。");
            if (i < 99) longText.append("\n\n");
        }

        List<String> chunks = knowledgeIndexService.splitText(longText.toString());

        assertThat(chunks).isNotEmpty();
        for (String chunk : chunks) {
            assertThat(chunk.length()).isLessThanOrEqualTo(600); // CHUNK_SIZE + some margin
        }
    }

    @Test
    void splitVeryLongSentenceWithoutPunctuation() {
        String text = "知".repeat(1600);

        List<String> chunks = knowledgeIndexService.splitText(text);

        assertThat(chunks).hasSizeGreaterThan(1);
        assertThat(chunks).allSatisfy(chunk -> assertThat(chunk.length()).isLessThanOrEqualTo(500));
    }

    @Test
    void indexDocumentSuccessfully() {
        UUID docId = UUID.randomUUID();
        KnowledgeDoc doc = new KnowledgeDoc("测试文档", KnowledgeSourceType.MANUAL, null, "测试内容", true);

        when(knowledgeDocRepository.findById(docId)).thenReturn(Optional.of(doc));
        when(embeddingService.embed(any(String.class))).thenReturn(new float[768]);

        knowledgeIndexService.indexDocument(docId);

        verify(knowledgeChunkRepository).deleteByDocId(docId);
        verify(knowledgeChunkRepository).save(any(KnowledgeChunk.class));
    }

    @Test
    void keepsTextSearchableWhenEmbeddingGenerationFails() {
        UUID docId = UUID.randomUUID();
        KnowledgeDoc doc = new KnowledgeDoc("测试文档", KnowledgeSourceType.MANUAL, null, "测试内容", true);
        when(knowledgeDocRepository.findById(docId)).thenReturn(Optional.of(doc));
        when(embeddingService.embed(any(String.class))).thenThrow(new IllegalStateException("offline"));

        knowledgeIndexService.indexDocument(docId);

        ArgumentCaptor<KnowledgeChunk> captor = ArgumentCaptor.forClass(KnowledgeChunk.class);
        verify(knowledgeChunkRepository).save(captor.capture());
        assertThat(captor.getValue().getEmbedding()).isNull();
        assertThat(captor.getValue().getMetadata()).contains("embedding_generation_failed");
        assertThat(captor.getValue().getContent()).isEqualTo("测试内容");
    }

    @Test
    void indexesContentFromThePublicContentSnapshot() {
        UUID contentId = UUID.randomUUID();
        when(contentKnowledgeService.findIndexable(contentId)).thenReturn(Optional.of(
                new ContentKnowledgeSource(contentId, "标题", "摘要", "正文")
        ));
        when(embeddingService.embed(any(String.class))).thenReturn(new float[768]);

        knowledgeIndexService.indexContent(contentId);

        verify(knowledgeChunkRepository).deleteByContentId(contentId);
        ArgumentCaptor<KnowledgeChunk> captor = ArgumentCaptor.forClass(KnowledgeChunk.class);
        verify(knowledgeChunkRepository).save(captor.capture());
        assertThat(captor.getValue().getContentId()).isEqualTo(contentId);
        assertThat(captor.getValue().getContent()).contains("标题", "摘要", "正文");
    }
}
