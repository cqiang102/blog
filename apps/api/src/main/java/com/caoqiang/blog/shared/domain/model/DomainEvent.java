package com.caoqiang.blog.shared.domain.model;

import java.time.Instant;
import java.util.UUID;

/**
 * 领域事件基类
 * <p>
 * 所有领域事件的抽象基类，提供事件的唯一标识和发生时间。
 * 领域事件表示领域中发生的有意义的事情，用于实现聚合根之间的松耦合通信。
 * <p>
 * 核心属性：
 * <ul>
 *   <li>{@code eventId} - 事件唯一标识，用于事件追踪和去重</li>
 *   <li>{@code occurredAt} - 事件发生时间，用于事件排序和审计</li>
 * </ul>
 * <p>
 * 使用方式：
 * <pre>
 * public class OrderCompletedEvent extends DomainEvent {
 *     private final UUID orderId;
 *     
 *     public OrderCompletedEvent(UUID orderId) {
 *         this.orderId = orderId;
 *     }
 * }
 * </pre>
 */
public abstract class DomainEvent {

    /** 事件唯一标识 */
    private final UUID eventId = UUID.randomUUID();

    /** 事件发生时间 */
    private final Instant occurredAt = Instant.now();

    /**
     * 获取事件唯一标识
     *
     * @return UUID 格式的事件标识
     */
    public UUID getEventId() {
        return eventId;
    }

    /**
     * 获取事件发生时间
     *
     * @return 事件发生的精确时间
     */
    public Instant getOccurredAt() {
        return occurredAt;
    }
}
