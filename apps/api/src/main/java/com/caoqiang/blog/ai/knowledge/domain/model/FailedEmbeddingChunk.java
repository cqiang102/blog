package com.caoqiang.blog.ai.knowledge.domain.model;

import java.util.UUID;

/** Read-only projection used to retry a failed embedding without keeping a JPA entity attached. */
public interface FailedEmbeddingChunk {

    UUID getId();

    String getContent();
}
