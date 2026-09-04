package com.caoqiang.blog.content;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.reset;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.caoqiang.blog.config.CacheNames;
import com.caoqiang.blog.content.application.event.ContentCacheEventListener;
import com.caoqiang.blog.content.application.service.FeedQueryService;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.repository.ContentRepository.FeedEntryProjection;
import com.caoqiang.blog.content.event.ContentArchivedEvent;
import com.caoqiang.blog.content.event.ContentPublishedEvent;
import java.io.StringReader;
import java.time.Clock;
import java.time.Instant;
import java.time.ZoneOffset;
import java.util.List;
import java.util.UUID;
import javax.xml.parsers.DocumentBuilderFactory;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.concurrent.ConcurrentMapCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.test.context.junit.jupiter.SpringJUnitConfig;
import org.w3c.dom.Document;
import org.xml.sax.InputSource;

@SpringJUnitConfig(FeedQueryServiceTest.Config.class)
class FeedQueryServiceTest {

    private static final String ATOM = "http://www.w3.org/2005/Atom";
    private static final Instant NOW = Instant.parse("2026-09-04T00:00:00Z");
    private static final Instant PUBLISHED = NOW.minusSeconds(3600);
    private static final UUID ID = UUID.fromString("00000000-0000-0000-0000-000000000001");

    @Autowired
    private FeedQueryService service;

    @Autowired
    private ContentRepository repository;

    @Autowired
    private CacheManager cacheManager;

    @BeforeEach
    void resetCache() {
        reset(repository);
        cacheManager.getCache(CacheNames.ATOM_FEED).clear();
    }

    @Test
    void generatesValidAtomWithEscapedTextStableIdsAndAbsoluteLinks() throws Exception {
        var entry = entry("中文 & <标签> 😀", "摘要 & <script>文本</script>" + (char) 1, NOW);
        returns(List.of(entry));

        String body = service.atom();
        var document = parse(body);

        assertThat(document.getDocumentElement().getNamespaceURI()).isEqualTo(ATOM);
        assertThat(text(document, "title", 0)).isEqualTo("沐凉 & 日记");
        assertThat(text(document, "name", 0)).isEqualTo("沐凉");
        assertThat(text(document, "id", 0)).isEqualTo("https://blog.lacia.cn/atom.xml");
        assertThat(text(document, "id", 1)).isEqualTo("urn:uuid:" + ID);
        assertThat(text(document, "title", 1)).isEqualTo("中文 & <标签> 😀");
        assertThat(text(document, "summary", 0)).isEqualTo("摘要 & <script>文本</script>");
        assertThat(text(document, "published", 0)).isEqualTo(PUBLISHED.toString());
        assertThat(text(document, "updated", 0)).isEqualTo(NOW.toString());
        assertThat(text(document, "updated", 1)).isEqualTo(NOW.toString());
        assertThat(body).contains("href=\"https://blog.lacia.cn/contents/" + ID + "\"");
        assertThat(body).contains("rel=\"self\"", "type=\"text\"");
        assertThat(document.getElementsByTagName("script").getLength()).isZero();
    }

    @Test
    void fallsBackForMissingSummaryAndNeverReportsAnUpdateBeforePublication() throws Exception {
        returns(List.of(entry("文章", "  ", PUBLISHED.minusSeconds(1))));

        var document = parse(service.atom());

        assertThat(text(document, "summary", 0)).isEqualTo("阅读全文");
        assertThat(text(document, "updated", 1)).isEqualTo(PUBLISHED.toString());
    }

    @Test
    void emptyFeedStaysValidAndStableAfterCacheExpiry() throws Exception {
        returns(List.of());
        String first = service.atom();
        cacheManager.getCache(CacheNames.ATOM_FEED).clear();

        String second = service.atom();

        assertThat(second).isEqualTo(first);
        var document = parse(second);
        assertThat(document.getElementsByTagNameNS(ATOM, "entry").getLength()).isZero();
        assertThat(text(document, "updated", 0)).isEqualTo(Instant.EPOCH.toString());
    }

    @Test
    void cachesXmlAndRefreshesItForEditsAndRemoval() {
        returns(List.of(entry("原文章", "原摘要", PUBLISHED)));
        String original = service.atom();
        assertThat(service.atom()).isEqualTo(original);
        var listener = new ContentCacheEventListener(cacheManager);

        returns(List.of(entry("已编辑", "新摘要", NOW)));
        listener.onContentPublished(new ContentPublishedEvent(ID, "已编辑", "article"));
        assertThat(service.atom()).contains("已编辑").isNotEqualTo(original);

        returns(List.of());
        listener.onContentArchived(new ContentArchivedEvent(ID));
        assertThat(service.atom()).doesNotContain("<entry>");
        verify(repository, times(3))
                .findTop20ByTypeAndStatusAndDeletedAtIsNullAndPublishedAtLessThanEqualOrderByPublishedAtDescIdDesc(
                        ContentType.ARTICLE, ContentStatus.PUBLISHED, NOW);
    }

    private void returns(List<FeedEntryProjection> entries) {
        when(repository
                        .findTop20ByTypeAndStatusAndDeletedAtIsNullAndPublishedAtLessThanEqualOrderByPublishedAtDescIdDesc(
                                ContentType.ARTICLE, ContentStatus.PUBLISHED, NOW))
                .thenReturn(entries);
    }

    private static FeedEntryProjection entry(String title, String summary, Instant updated) {
        var entry = mock(FeedEntryProjection.class);
        when(entry.getId()).thenReturn(ID);
        when(entry.getTitle()).thenReturn(title);
        when(entry.getSummary()).thenReturn(summary);
        when(entry.getPublishedAt()).thenReturn(PUBLISHED);
        when(entry.getUpdatedAt()).thenReturn(updated);
        return entry;
    }

    private static Document parse(String xml) throws Exception {
        var factory = DocumentBuilderFactory.newInstance();
        factory.setNamespaceAware(true);
        factory.setFeature("http://apache.org/xml/features/disallow-doctype-decl", true);
        return factory.newDocumentBuilder().parse(new InputSource(new StringReader(xml)));
    }

    private static String text(Document document, String name, int index) {
        return document.getElementsByTagNameNS(ATOM, name).item(index).getTextContent();
    }

    @Configuration(proxyBeanMethods = false)
    @EnableCaching
    static class Config {
        @Bean
        ContentRepository repository() {
            return mock(ContentRepository.class);
        }

        @Bean
        CacheManager cacheManager() {
            return new ConcurrentMapCacheManager(CacheNames.ATOM_FEED, CacheNames.RECOMMENDATIONS);
        }

        @Bean
        FeedQueryService service(ContentRepository repository) {
            return new FeedQueryService(
                    repository, Clock.fixed(NOW, ZoneOffset.UTC), "https://blog.lacia.cn/", "沐凉 & 日记", "沐凉");
        }
    }
}
