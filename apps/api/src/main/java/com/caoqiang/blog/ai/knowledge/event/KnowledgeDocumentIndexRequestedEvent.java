package com.caoqiang.blog.ai.knowledge.event;

import java.util.UUID;

/** Requests indexing after the knowledge-document transaction has committed. */
public record KnowledgeDocumentIndexRequestedEvent(UUID documentId) {}
