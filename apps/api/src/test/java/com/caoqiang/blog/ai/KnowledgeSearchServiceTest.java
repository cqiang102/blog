package com.caoqiang.blog.ai;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.ai.knowledge.application.dto.KnowledgeSearchResult;
import com.caoqiang.blog.ai.knowledge.application.service.EmbeddingService;
import com.caoqiang.blog.ai.knowledge.application.service.KnowledgeSearchService;
import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeDoc;
import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeSourceType;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeChunkRepository;
import com.caoqiang.blog.ai.knowledge.domain.repository.KnowledgeDocRepository;
import com.caoqiang.blog.config.BlogProperties;
import com.caoqiang.blog.content.application.api.ContentKnowledgeService;
import com.caoqiang.blog.content.application.api.ContentKnowledgeSource;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class KnowledgeSearchServiceTest {

    @Mock
    private ContentKnowledgeService contentKnowledgeService;
    @Mock
    private KnowledgeChunkRepository knowledgeChunkRepository;
    @Mock
    private KnowledgeDocRepository knowledgeDocRepository;
    @Mock
    private EmbeddingService embeddingService;

    private KnowledgeSearchService service;

    @BeforeEach
    void setUp() {
        BlogProperties properties = new BlogProperties();
        properties.getAi().setKnowledgeMinSimilarity(0.60);
        service = new KnowledgeSearchService(
                properties,
                contentKnowledgeService,
                knowledgeChunkRepository,
                knowledgeDocRepository,
                embeddingService
        );
    }

    @Test
    void blankQueryBrowsesKnowledgeAndPublishedContentWithoutEmbedding() {
        KnowledgeDoc doc = new KnowledgeDoc(
                "博主简介",
                KnowledgeSourceType.MANUAL,
                null,
                "Java 后端开发",
                true
        );
        ContentKnowledgeSource content = new ContentKnowledgeSource(
                UUID.randomUUID(),
                "测试文章",
                "文章摘要",
                null
        );
        when(knowledgeDocRepository.findByEnabledTrueOrderByUpdatedAtDesc(any()))
                .thenReturn(List.of(doc));
        when(contentKnowledgeService.searchPublished(null, 4)).thenReturn(List.of(content));

        List<KnowledgeSearchResult> results = service.search(" ");

        assertThat(results).extracting(KnowledgeSearchResult::title)
                .containsExactly("博主简介", "测试文章");
        verify(embeddingService, never()).embed(any(String.class));
    }

    @Test
    void exactKeywordResultWinsWithoutVectorSearch() {
        KnowledgeDoc doc = new KnowledgeDoc(
                "博主简介",
                KnowledgeSourceType.MANUAL,
                null,
                "我是 Java 后端开发者",
                true
        );
        when(knowledgeDocRepository.searchEnabled(eq("Java"), any()))
                .thenReturn(List.of(doc));
        when(contentKnowledgeService.searchPublished("Java", 5)).thenReturn(List.of());

        List<KnowledgeSearchResult> results = service.search("Java");

        assertThat(results).singleElement().satisfies(result -> {
            assertThat(result.title()).isEqualTo("博主简介");
            assertThat(result.score()).isEqualTo(1.0);
            assertThat(result.content()).contains("Java");
        });
        verify(embeddingService, never()).embed(any(String.class));
    }

    @Test
    void keywordExcerptIncludesMatchesNearTheEndOfLongDocuments() {
        KnowledgeDoc doc = new KnowledgeDoc(
                "长文档",
                KnowledgeSourceType.MANUAL,
                null,
                "前文".repeat(700) + "目标关键词" + "后文".repeat(100),
                true
        );
        when(knowledgeDocRepository.searchEnabled(eq("目标关键词"), any()))
                .thenReturn(List.of(doc));
        when(contentKnowledgeService.searchPublished("目标关键词", 5)).thenReturn(List.of());

        List<KnowledgeSearchResult> results = service.search("目标关键词");

        assertThat(results).singleElement()
                .extracting(KnowledgeSearchResult::content)
                .asString()
                .contains("目标关键词");
    }

    @Test
    void filtersLowSimilarityVectorCandidates() {
        UUID docId = UUID.randomUUID();
        when(knowledgeDocRepository.searchEnabled(eq("量子引力"), any())).thenReturn(List.of());
        when(contentKnowledgeService.searchPublished("量子引力", 5)).thenReturn(List.of());
        when(embeddingService.embed("量子引力")).thenReturn(new float[768]);
        when(knowledgeChunkRepository.findSimilarChunks(any(String.class), anyInt()))
                .thenReturn(List.<Object[]>of(new Object[]{
                        UUID.randomUUID(), docId, null, 0, "无关片段", null, 0.59
                }));

        assertThat(service.search("量子引力")).isEmpty();
        verify(knowledgeDocRepository, never()).findAllById(any());
        verify(contentKnowledgeService, never()).findPublishedByIds(any());
    }

    @Test
    void returnsRelevantVectorCandidateWithSourceTitle() {
        KnowledgeDoc doc = new KnowledgeDoc(
                "博主简介",
                KnowledgeSourceType.MANUAL,
                null,
                "我是 Java 后端开发者",
                true
        );
        when(knowledgeDocRepository.searchEnabled(eq("博主是谁"), any())).thenReturn(List.of());
        when(contentKnowledgeService.searchPublished("博主是谁", 5)).thenReturn(List.of());
        when(embeddingService.embed("博主是谁")).thenReturn(new float[768]);
        when(knowledgeChunkRepository.findSimilarChunks(any(String.class), eq(25)))
                .thenReturn(List.<Object[]>of(new Object[]{
                        UUID.randomUUID(), doc.getId(), null, 0, "我是 Java 后端开发者", null, 0.66
                }));
        when(knowledgeDocRepository.findAllById(List.of(doc.getId()))).thenReturn(List.of(doc));

        List<KnowledgeSearchResult> results = service.search("博主是谁");

        assertThat(results).singleElement().satisfies(result -> {
            assertThat(result.title()).isEqualTo("博主简介");
            assertThat(result.score()).isEqualTo(0.66);
        });
    }

    @Test
    void deduplicatesVectorCandidatesFromTheSameSource() {
        KnowledgeDoc doc = new KnowledgeDoc(
                "博主简介",
                KnowledgeSourceType.MANUAL,
                null,
                "我是 Java 后端开发者",
                true
        );
        when(knowledgeDocRepository.searchEnabled(eq("服务端工程"), any())).thenReturn(List.of());
        when(contentKnowledgeService.searchPublished("服务端工程", 5)).thenReturn(List.of());
        when(embeddingService.embed("服务端工程")).thenReturn(new float[768]);
        when(knowledgeChunkRepository.findSimilarChunks(any(String.class), eq(25)))
                .thenReturn(List.of(
                        new Object[]{
                                UUID.randomUUID(), doc.getId(), null, 0,
                                "第一段", null, 0.78
                        },
                        new Object[]{
                                UUID.randomUUID(), doc.getId(), null, 1,
                                "第二段", null, 0.71
                        }
                ));
        when(knowledgeDocRepository.findAllById(List.of(doc.getId()))).thenReturn(List.of(doc));

        List<KnowledgeSearchResult> results = service.search("服务端工程");

        assertThat(results).singleElement().satisfies(result -> {
            assertThat(result.content()).isEqualTo("第一段");
            assertThat(result.score()).isEqualTo(0.78);
        });
    }

}
