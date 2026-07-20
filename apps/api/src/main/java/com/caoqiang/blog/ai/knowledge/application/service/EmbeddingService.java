package com.caoqiang.blog.ai.knowledge.application.service;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.embedding.EmbeddingModel;
import org.springframework.retry.annotation.Retryable;
import org.springframework.stereotype.Service;

/**
 * 嵌入模型调用服务，提供重试机制。
 * <p>
 * 封装 Spring AI 的 {@link EmbeddingModel}，在调用失败时自动重试，
 * 提高嵌入模型服务的可用性。
 */
@Service
public class EmbeddingService {

    private static final Logger log = LoggerFactory.getLogger(EmbeddingService.class);

    /** 嵌入向量维度 */
    private static final int EMBEDDING_DIMENSIONS = 768;

    private final EmbeddingModel embeddingModel;

    public EmbeddingService(EmbeddingModel embeddingModel) {
        this.embeddingModel = embeddingModel;
    }

    /**
     * 生成文本的向量嵌入，支持重试。
     * <p>
     * 当嵌入模型调用失败时，会自动重试最多 3 次，每次重试间隔指数退避。
     *
     * @param text 待嵌入的文本
     * @return 768 维的浮点数组
     * @throws IllegalStateException 如果嵌入结果为空或维度不正确
     */
    @Retryable(
            retryFor = {Exception.class},
            maxAttempts = 3,
            backoff = @org.springframework.retry.annotation.Backoff(delay = 1000, multiplier = 2))
    public float[] embed(String text) {
        log.debug("Calling embedding model for text length: {}", text.length());
        float[] embedding = embeddingModel.embed(text);

        if (embedding == null || embedding.length != EMBEDDING_DIMENSIONS) {
            throw new IllegalStateException("Expected " + EMBEDDING_DIMENSIONS + " dimensions but got "
                    + (embedding == null ? "null" : embedding.length));
        }

        return embedding;
    }
}
