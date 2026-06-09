package com.caoqiang.blog.friend.domain.repository;

import com.caoqiang.blog.friend.domain.model.Friend;

import java.util.List;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * 友链数据访问层
 * <p>
 * 继承 {@link JpaRepository} 提供基本 CRUD 操作。
 * <p>
 * 提供按排序权重和创建时间排序的查询方法，
 * 用于前台展示和后台管理。
 */
public interface FriendRepository extends JpaRepository<Friend, UUID> {

    /**
     * 查询所有可见友链
     * <p>
     * 按排序权重升序、创建时间降序排列。
     * 用于前台页面展示。
     *
     * @return 可见友链列表
     */
    List<Friend> findByVisibleTrueOrderBySortOrderAscCreatedAtDesc();

    /**
     * 查询所有友链
     * <p>
     * 按排序权重升序、创建时间降序排列。
     * 用于管理后台展示。
     *
     * @return 所有友链列表
     */
    List<Friend> findAllByOrderBySortOrderAscCreatedAtDesc();
}
