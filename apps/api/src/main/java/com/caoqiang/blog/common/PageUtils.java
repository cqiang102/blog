package com.caoqiang.blog.common;

import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

/**
 * 分页工具类。
 * <p>
 * 提供统一的分页请求构建方法，避免在多个 Service 中重复实现参数校验逻辑。
 *
 * @author caoqiang
 */
public final class PageUtils {

    /** 默认最大分页大小 */
    public static final int DEFAULT_MAX_SIZE = 50;

    private PageUtils() {
    }

    /**
     * 创建分页请求对象（使用默认最大分页大小）。
     *
     * @param page 页码（从 0 开始）
     * @param size 每页大小
     * @param sort 排序方式
     * @return 分页请求对象
     */
    public static PageRequest of(int page, int size, Sort sort) {
        return of(page, size, DEFAULT_MAX_SIZE, sort);
    }

    /**
     * 创建分页请求对象。
     * <p>
     * 对参数进行边界检查：page >= 0, 1 <= size <= maxSize
     *
     * @param page    页码（从 0 开始）
     * @param size    每页大小
     * @param maxSize 最大分页大小限制
     * @param sort    排序方式
     * @return 分页请求对象
     */
    public static PageRequest of(int page, int size, int maxSize, Sort sort) {
        return PageRequest.of(
                Math.max(0, page),
                Math.max(1, Math.min(size, maxSize)),
                sort
        );
    }
}
