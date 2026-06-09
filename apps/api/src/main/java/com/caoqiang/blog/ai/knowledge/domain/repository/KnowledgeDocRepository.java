package com.caoqiang.blog.ai.knowledge.domain.repository;

import com.caoqiang.blog.ai.knowledge.domain.model.KnowledgeDoc;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;

/**
 * 知识文档 Repository。
 * <p>
 * 提供知识文档实体的 CRUD 操作，同时实现 {@link JpaSpecificationExecutor}
 * 以支持动态条件查询（管理端按关键词、启用状态筛选）。
 */
public interface KnowledgeDocRepository extends JpaRepository<KnowledgeDoc, UUID>,
        JpaSpecificationExecutor<KnowledgeDoc> {
}
