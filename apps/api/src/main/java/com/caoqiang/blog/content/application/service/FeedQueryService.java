package com.caoqiang.blog.content.application.service;

import com.caoqiang.blog.config.CacheNames;
import com.caoqiang.blog.content.domain.model.ContentStatus;
import com.caoqiang.blog.content.domain.model.ContentType;
import com.caoqiang.blog.content.domain.repository.ContentRepository;
import com.caoqiang.blog.content.domain.repository.ContentRepository.FeedEntryProjection;
import java.io.StringWriter;
import java.time.Clock;
import java.time.Instant;
import javax.xml.stream.XMLOutputFactory;
import javax.xml.stream.XMLStreamException;
import javax.xml.stream.XMLStreamWriter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.cache.annotation.Cacheable;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.util.StringUtils;

/** Generates a public, summary-only Atom feed without user-specific data. */
@Service
public class FeedQueryService {

    private final ContentRepository contentRepository;
    private final Clock clock;
    private final String baseUrl;
    private final String title;
    private final String author;

    public FeedQueryService(
            ContentRepository contentRepository,
            Clock clock,
            @Value("${blog.frontend.base-url}") String baseUrl,
            @Value("${blog.feed.title:沐凉·日记}") String title,
            @Value("${blog.feed.author:沐凉}") String author) {
        this.contentRepository = contentRepository;
        this.clock = clock;
        this.baseUrl = baseUrl.strip().replaceFirst("/+$", "");
        this.title = title;
        this.author = author;
    }

    @Transactional(readOnly = true)
    @Cacheable(value = CacheNames.ATOM_FEED, key = "'atom'", sync = true)
    public String atom() {
        var entries =
                contentRepository
                        .findTop20ByTypeAndStatusAndDeletedAtIsNullAndPublishedAtLessThanEqualOrderByPublishedAtDescIdDesc(
                                ContentType.ARTICLE, ContentStatus.PUBLISHED, clock.instant());
        // A fixed fallback keeps an empty feed stable across requests and cache expiry.
        Instant updated = entries.stream()
                .map(FeedQueryService::updatedAt)
                .max(Instant::compareTo)
                .orElse(Instant.EPOCH);

        try {
            var output = new StringWriter();
            var xml = XMLOutputFactory.newFactory().createXMLStreamWriter(output);
            xml.writeStartDocument("UTF-8", "1.0");
            xml.writeStartElement("feed");
            xml.writeDefaultNamespace("http://www.w3.org/2005/Atom");
            textElement(xml, "id", baseUrl + "/atom.xml");
            textElement(xml, "title", title);
            textElement(xml, "updated", updated.toString());
            link(xml, "self", baseUrl + "/atom.xml", "application/atom+xml");
            link(xml, "alternate", baseUrl + "/", "text/html");
            xml.writeStartElement("author");
            textElement(xml, "name", author);
            xml.writeEndElement();

            for (var entry : entries) {
                xml.writeStartElement("entry");
                textElement(xml, "id", "urn:uuid:" + entry.getId());
                textElement(xml, "title", entry.getTitle());
                link(xml, "alternate", baseUrl + "/contents/" + entry.getId(), "text/html");
                textElement(xml, "published", entry.getPublishedAt().toString());
                textElement(xml, "updated", updatedAt(entry).toString());
                xml.writeStartElement("summary");
                xml.writeAttribute("type", "text");
                xml.writeCharacters(xmlText(
                        StringUtils.hasText(entry.getSummary())
                                ? entry.getSummary().strip()
                                : "阅读全文"));
                xml.writeEndElement();
                xml.writeEndElement();
            }
            xml.writeEndElement();
            xml.writeEndDocument();
            xml.close();
            return output.toString();
        } catch (XMLStreamException exception) {
            throw new IllegalStateException("Unable to generate Atom feed", exception);
        }
    }

    private static Instant updatedAt(FeedEntryProjection entry) {
        var updated = entry.getUpdatedAt();
        return updated == null || updated.isBefore(entry.getPublishedAt()) ? entry.getPublishedAt() : updated;
    }

    private static void textElement(XMLStreamWriter xml, String name, String value) throws XMLStreamException {
        xml.writeStartElement(name);
        xml.writeCharacters(xmlText(value));
        xml.writeEndElement();
    }

    private static void link(XMLStreamWriter xml, String rel, String href, String type) throws XMLStreamException {
        xml.writeEmptyElement("link");
        xml.writeAttribute("rel", rel);
        xml.writeAttribute("href", href);
        xml.writeAttribute("type", type);
    }

    /** Strip characters XML 1.0 cannot represent, including pasted controls and unpaired surrogates. */
    private static String xmlText(String value) {
        var result = new StringBuilder();
        value.codePoints()
                .filter(code -> code == 0x9
                        || code == 0xA
                        || code == 0xD
                        || (code >= 0x20 && code <= 0xD7FF)
                        || (code >= 0xE000 && code <= 0xFFFD)
                        || (code >= 0x10000 && code <= 0x10FFFF))
                .forEach(result::appendCodePoint);
        return result.toString();
    }
}
