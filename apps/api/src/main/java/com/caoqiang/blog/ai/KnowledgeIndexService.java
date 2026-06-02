package com.caoqiang.blog.ai;

import com.caoqiang.blog.content.Content;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class KnowledgeIndexService {

    private static final int CHUNK_SIZE = 500;
    private static final int CHUNK_OVERLAP = 50;

    private final KnowledgeDocRepository knowledgeDocRepository;
    private final KnowledgeChunkRepository knowledgeChunkRepository;
    private final EmbeddingModel embeddingModel;

    public KnowledgeIndexService(
            KnowledgeDocRepository knowledgeDocRepository,
            KnowledgeChunkRepository knowledgeChunkRepository,
            EmbeddingModel embeddingModel
    ) {
        this.knowledgeDocRepository = knowledgeDocRepository;
        this.knowledgeChunkRepository = knowledgeChunkRepository;
        this.embeddingModel = embeddingModel;
    }

    @Transactional
    public void indexDocument(UUID docId) {
        KnowledgeDoc doc = knowledgeDocRepository.findById(docId)
                .orElseThrow(() -> new IllegalArgumentException("知识库文档不存在: " + docId));

        knowledgeChunkRepository.deleteByDocId(docId);

        if (doc.getBody() == null || doc.getBody().isBlank()) {
            return;
        }

        List<String> chunks = splitText(doc.getBody());
        for (int i = 0; i < chunks.size(); i++) {
            String chunkContent = chunks.get(i);
            KnowledgeChunk chunk = new KnowledgeChunk(doc, i, chunkContent);

            try {
                float[] embedding = embeddingModel.embed(chunkContent);
                chunk.setEmbedding(vectorToString(embedding));
            } catch (Exception e) {
                // Embedding 生成失败时仍然保存文本，但不包含向量
                chunk.setMetadata("{\"error\": \"embedding generation failed\"}");
            }

            knowledgeChunkRepository.save(chunk);
        }
    }

    @Transactional
    public void indexContent(Content content) {
        // 先删除该内容的旧索引
        knowledgeChunkRepository.deleteByContentId(content.getId());

        // 构建要索引的文本：标题 + 摘要 + 正文
        StringBuilder textBuilder = new StringBuilder();
        if (content.getTitle() != null && !content.getTitle().isBlank()) {
            textBuilder.append(content.getTitle()).append("\n\n");
        }
        if (content.getSummary() != null && !content.getSummary().isBlank()) {
            textBuilder.append(content.getSummary()).append("\n\n");
        }
        if (content.getBodyMarkdown() != null && !content.getBodyMarkdown().isBlank()) {
            textBuilder.append(content.getBodyMarkdown());
        }

        String fullText = textBuilder.toString().trim();
        if (fullText.isEmpty()) {
            return;
        }

        List<String> chunks = splitText(fullText);
        for (int i = 0; i < chunks.size(); i++) {
            String chunkContent = chunks.get(i);
            KnowledgeChunk chunk = new KnowledgeChunk(content.getId(), i, chunkContent);

            try {
                float[] embedding = embeddingModel.embed(chunkContent);
                chunk.setEmbedding(vectorToString(embedding));
            } catch (Exception e) {
                chunk.setMetadata("{\"error\": \"embedding generation failed\"}");
            }

            knowledgeChunkRepository.save(chunk);
        }
    }

    @Transactional
    public void deleteContentIndex(UUID contentId) {
        knowledgeChunkRepository.deleteByContentId(contentId);
    }

    @Transactional
    public void indexAllDocuments() {
        List<KnowledgeDoc> docs = knowledgeDocRepository.findAll();
        for (KnowledgeDoc doc : docs) {
            if (doc.isEnabled()) {
                try {
                    indexDocument(doc.getId());
                } catch (Exception e) {
                    // 记录错误但继续处理其他文档
                    System.err.println("Failed to index document " + doc.getId() + ": " + e.getMessage());
                }
            }
        }
    }

    public List<String> splitText(String text) {
        List<String> chunks = new ArrayList<>();
        if (text == null || text.isBlank()) {
            return chunks;
        }

        String[] paragraphs = text.split("\n\n+");
        StringBuilder currentChunk = new StringBuilder();

        for (String paragraph : paragraphs) {
            paragraph = paragraph.trim();
            if (paragraph.isEmpty()) continue;

            if (currentChunk.length() + paragraph.length() + 2 > CHUNK_SIZE) {
                if (currentChunk.length() > 0) {
                    chunks.add(currentChunk.toString().trim());
                    String overlap = getOverlap(currentChunk.toString());
                    currentChunk = new StringBuilder(overlap);
                }
            }

            if (paragraph.length() > CHUNK_SIZE) {
                List<String> subChunks = splitLongParagraph(paragraph);
                for (String subChunk : subChunks) {
                    if (currentChunk.length() + subChunk.length() + 2 > CHUNK_SIZE) {
                        if (currentChunk.length() > 0) {
                            chunks.add(currentChunk.toString().trim());
                            currentChunk = new StringBuilder();
                        }
                    }
                    currentChunk.append(subChunk).append("\n\n");
                }
            } else {
                currentChunk.append(paragraph).append("\n\n");
            }
        }

        if (currentChunk.length() > 0) {
            chunks.add(currentChunk.toString().trim());
        }

        return chunks;
    }

    private List<String> splitLongParagraph(String paragraph) {
        List<String> parts = new ArrayList<>();
        String[] sentences = paragraph.split("(?<=[。！？.!?])\\s*");

        StringBuilder current = new StringBuilder();
        for (String sentence : sentences) {
            if (current.length() + sentence.length() > CHUNK_SIZE) {
                if (current.length() > 0) {
                    parts.add(current.toString().trim());
                }
                current = new StringBuilder(sentence);
            } else {
                current.append(sentence);
            }
        }

        if (current.length() > 0) {
            parts.add(current.toString().trim());
        }

        return parts;
    }

    private String getOverlap(String text) {
        if (text.length() <= CHUNK_OVERLAP) {
            return text;
        }
        return text.substring(text.length() - CHUNK_OVERLAP);
    }

    private String vectorToString(float[] embedding) {
        StringBuilder sb = new StringBuilder("[");
        for (int i = 0; i < embedding.length; i++) {
            if (i > 0) sb.append(",");
            sb.append(embedding[i]);
        }
        sb.append("]");
        return sb.toString();
    }
}
