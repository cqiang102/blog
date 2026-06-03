package com.caoqiang.blog.content;

import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 媒体资源数据访问接口。
 * <p>
 * 继承 {@link JpaRepository} 提供基础 CRUD，额外提供按内容 ID 分页查询的能力。
 */
public interface MediaAssetRepository extends JpaRepository<MediaAsset, UUID> {

    /**
     * 根据所属内容 ID 分页查询媒体资源。
     *
     * @param contentId 内容 UUID
     * @param pageable  分页参数
     * @return 分页媒体资源结果
     */
    Page<MediaAsset> findByContentId(UUID contentId, Pageable pageable);
}
