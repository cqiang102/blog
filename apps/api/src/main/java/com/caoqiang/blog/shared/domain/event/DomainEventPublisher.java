package com.caoqiang.blog.shared.domain.event;

import com.caoqiang.blog.shared.domain.model.AggregateRoot;
import com.caoqiang.blog.shared.domain.model.DomainEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

/**
 * 领域事件发布器
 * <p>
 * 封装 Spring 的 {@link ApplicationEventPublisher}，提供领域事件的发布能力。
 * 支持两种发布方式：
 * <ul>
 *   <li>从聚合根批量发布 - 发布聚合根中收集的所有事件并清空</li>
 *   <li>直接发布单个事件 - 适用于非聚合根场景</li>
 * </ul>
 * <p>
 * 使用方式：
 * <pre>
 * // 方式1：从聚合根发布
 * domainEventPublisher.publishEvents(order);
 *
 * // 方式2：直接发布
 * domainEventPublisher.publishEvent(new OrderCreatedEvent(orderId));
 * </pre>
 */
@Component
public class DomainEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(DomainEventPublisher.class);

    /** Spring 事件发布器 */
    private final ApplicationEventPublisher publisher;

    /**
     * 构造函数，注入 Spring 事件发布器
     *
     * @param publisher Spring 应用事件发布器
     */
    public DomainEventPublisher(ApplicationEventPublisher publisher) {
        this.publisher = publisher;
    }

    /**
     * 发布聚合根中的所有领域事件
     * <p>
     * 遍历聚合根中收集的所有事件并逐一发布，发布完成后清空事件列表。
     * 通常在 Service 层的事务方法中调用。
     *
     * @param aggregate 聚合根实体
     */
    public void publishEvents(AggregateRoot aggregate) {
        for (DomainEvent event : aggregate.getDomainEvents()) {
            log.debug("Publishing domain event: {}", event.getClass().getSimpleName());
            publisher.publishEvent(event);
        }
        aggregate.clearEvents();
    }

    /**
     * 发布单个领域事件
     * <p>
     * 直接发布事件，不依赖聚合根。
     * 适用于 Service 层直接创建和发布事件的场景。
     *
     * @param event 要发布的领域事件
     */
    public void publishEvent(DomainEvent event) {
        log.debug("Publishing domain event: {}", event.getClass().getSimpleName());
        publisher.publishEvent(event);
    }
}
