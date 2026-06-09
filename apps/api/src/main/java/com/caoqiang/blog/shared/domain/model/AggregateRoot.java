package com.caoqiang.blog.shared.domain.model;

import jakarta.persistence.Id;
import jakarta.persistence.MappedSuperclass;
import jakarta.persistence.Transient;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

/**
 * 聚合根基类
 * <p>
 * DDD 聚合根的抽象基类，提供统一的身份标识和领域事件收集能力。
 * 所有聚合根实体都应继承此类。
 * <p>
 * 核心职责：
 * <ul>
 *   <li>提供 UUID 主键标识</li>
 *   <li>收集领域事件（{@link DomainEvent}）</li>
 *   <li>支持事件的批量发布和清理</li>
 * </ul>
 * <p>
 * 使用方式：
 * <pre>
 * public class Order extends AggregateRoot {
 *     public void complete() {
 *         // 业务逻辑
 *         registerEvent(new OrderCompletedEvent(this.getId()));
 *     }
 * }
 * </pre>
 */
@MappedSuperclass
public abstract class AggregateRoot {

    /** 聚合根唯一标识，UUID 格式 */
    @Id
    @jakarta.persistence.Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    /** 已注册的领域事件列表（不持久化） */
    @Transient
    private final List<DomainEvent> domainEvents = new ArrayList<>();

    /** JPA 受保护的无参构造函数 */
    protected AggregateRoot() {
    }

    /**
     * 使用指定 ID 创建聚合根
     *
     * @param id 聚合根唯一标识
     */
    protected AggregateRoot(UUID id) {
        this.id = id;
    }

    /**
     * 获取聚合根唯一标识
     *
     * @return UUID 格式的唯一标识
     */
    public UUID getId() {
        return id;
    }

    /**
     * 注册领域事件
     * <p>
     * 子类在完成业务操作后调用此方法注册事件，
     * 事件将在事务提交后由 {@link com.caoqiang.blog.shared.domain.event.DomainEventPublisher} 发布。
     *
     * @param event 要注册的领域事件
     */
    protected void registerEvent(DomainEvent event) {
        domainEvents.add(event);
    }

    /**
     * 获取所有已注册的领域事件（只读视图）
     *
     * @return 不可修改的事件列表
     */
    public List<DomainEvent> getDomainEvents() {
        return Collections.unmodifiableList(domainEvents);
    }

    /**
     * 清除所有已注册的领域事件
     * <p>
     * 通常由框架在事件发布后自动调用。
     */
    public void clearEvents() {
        domainEvents.clear();
    }
}
