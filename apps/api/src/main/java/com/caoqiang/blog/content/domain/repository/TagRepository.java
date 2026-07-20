package com.caoqiang.blog.content.domain.repository;

import com.caoqiang.blog.content.domain.model.Tag;
import java.util.Collection;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 标签数据访问接口。
 * <p>
 * 继承 {@link JpaRepository} 提供基础 CRUD，额外提供基于 slug 的查询方法。
 * slug 是标签的 URL 友好标识符，在创建和查询内容时广泛使用。
 */
public interface TagRepository extends JpaRepository<Tag, UUID> {

    /**
     * 根据 slug 查询标签。
     *
     * @param slug URL 标识符
     * @return 标签实体（若存在）
     */
    Optional<Tag> findBySlug(String slug);

    /**
     * 根据 slug 列表批量查询标签。
     * <p>
     * 用于内容创建/更新时根据 slug 列表关联标签。
     *
     * @param slugs slug 集合
     * @return 匹配的标签列表
     */
    List<Tag> findBySlugIn(Collection<String> slugs);

    /**
     * 检查 slug 是否已存在。
     *
     * @param slug URL 标识符
     * @return 是否存在
     */
    boolean existsBySlug(String slug);
}
