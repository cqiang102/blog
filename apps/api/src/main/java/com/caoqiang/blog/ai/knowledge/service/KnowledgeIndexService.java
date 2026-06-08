package com.caoqiang.blog.ai.knowledge.service;

import com.caoqiang.blog.ai.knowledge.entity.KnowledgeChunk;
import com.caoqiang.blog.ai.knowledge.entity.KnowledgeDoc;
import com.caoqiang.blog.ai.knowledge.entity.KnowledgeSourceType;
import com.caoqiang.blog.ai.knowledge.repository.KnowledgeChunkRepository;
import com.caoqiang.blog.ai.knowledge.repository.KnowledgeDocRepository;
import com.caoqiang.blog.shared.util.VectorUtils;
import com.caoqiang.blog.content.entity.Content;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 知识库索引服务。
 * <p>
 * 负责将知识文档和博客内容进行分块、向量嵌入并存储到数据库中，
 * 为 AI 聊天的向量相似度搜索提供数据基础。
 * <p>
 * 关键特性：
 * <ul>
 *   <li>文本分块：按段落边界切分，支持长段落按句子二次切分，块间有 {@value #CHUNK_OVERLAP} 字符重叠</li>
 *   <li>向量嵌入：使用 Spring AI {@link EmbeddingModel} 生成 768 维向量</li>
 *   <li>双重索引源：支持知识文档（{@link KnowledgeDoc}）和博客内容（{@link Content}）两种来源</li>
 * </ul>
 */
@Service
public class KnowledgeIndexService {

    private static final Logger log = LoggerFactory.getLogger(KnowledgeIndexService.class);

    /** 文本分块目标大小（字符数） */
    private static final int CHUNK_SIZE = 500;
    /** 相邻分块的重叠字符数 */
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

    /**
     * 对指定知识文档进行分块和向量索引。
     * <p>
     * 先删除该文档的旧索引，然后将文档正文按段落分块，
     * 为每个分块生成向量嵌入并保存。
     *
     * @param docId 知识文档 ID
     */
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
                chunk.setEmbedding(VectorUtils.toPgVectorString(embedding));
            } catch (Exception e) {
                // Embedding 生成失败时仍然保存文本，但不包含向量
                chunk.setMetadata("{\"error\": \"embedding generation failed\"}");
            }

            knowledgeChunkRepository.save(chunk);
        }
    }

    /**
     * 对博客内容进行分块和向量索引。
     * <p>
     * 将标题、摘要、正文拼接后分块，为每个分块生成向量嵌入并保存。
     * 索引时关联 contentId 以便后续按内容查询和删除。
     *
     * @param content 博客内容实体
     */
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
                chunk.setEmbedding(VectorUtils.toPgVectorString(embedding));
            } catch (Exception e) {
                chunk.setMetadata("{\"error\": \"embedding generation failed\"}");
            }

            knowledgeChunkRepository.save(chunk);
        }
    }

    /**
     * 删除指定博客内容的所有向量索引。
     *
     * @param contentId 博客内容 ID
     */
    @Transactional
    public void deleteContentIndex(UUID contentId) {
        knowledgeChunkRepository.deleteByContentId(contentId);
    }

    /**
     * 重新索引所有已启用的知识文档。
     * 单个文档索引失败不影响其他文档的处理。
     */
    @Transactional
    public void indexAllDocuments() {
        List<KnowledgeDoc> docs = knowledgeDocRepository.findAll();
        for (KnowledgeDoc doc : docs) {
            if (doc.isEnabled()) {
                try {
                    indexDocument(doc.getId());
                } catch (Exception e) {
                    // 记录错误但继续处理其他文档
                    log.error("Failed to index document {}: {}", doc.getId(), e.getMessage(), e);
                }
            }
        }
    }

    /**
     * 将长文本按段落边界切分为多个分块。
     * <p>
     * 策略：按双换行符分割段落，累积到 {@value #CHUNK_SIZE} 字符后切分，
     * 相邻分块保留 {@value #CHUNK_OVERLAP} 字符重叠以维持上下文连贯性。
     * 超长段落会按句子边界二次切分。
     *
     * @param text 待分块的文本
     * @return 分块后的文本列表
     */
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

    /** 将超长段落按句子边界（。！？.!?）切分为多个子块。 */
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

    /** 获取文本末尾的重叠部分，用于相邻分块的上下文衔接。 */
    private String getOverlap(String text) {
        if (text.length() <= CHUNK_OVERLAP) {
            return text;
        }
        return text.substring(text.length() - CHUNK_OVERLAP);
    }

}
