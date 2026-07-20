package com.caoqiang.blog.shared.response;

import java.util.List;

/**
 * 分页响应封装 record。
 * <p>
 * 用于返回分页查询结果，包含当前页数据列表、分页元信息和总记录数，
 * 方便前端实现分页渲染和总页数计算。
 *
 * @param items  当前页的数据列表
 * @param page   当前页码（从 0 开始）
 * @param size   每页大小
 * @param total  符合条件的总记录数
 * @param <T>    列表元素类型
 */
public record PageResponse<T>(List<T> items, int page, int size, long total) {}
