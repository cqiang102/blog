package com.caoqiang.blog.shared.domain.event;

import com.caoqiang.blog.shared.domain.model.AggregateRoot;
import com.caoqiang.blog.shared.domain.model.DomainEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.stereotype.Component;

@Component
public class DomainEventPublisher {

    private static final Logger log = LoggerFactory.getLogger(DomainEventPublisher.class);

    private final ApplicationEventPublisher publisher;

    public DomainEventPublisher(ApplicationEventPublisher publisher) {
        this.publisher = publisher;
    }

    public void publishEvents(AggregateRoot aggregate) {
        for (DomainEvent event : aggregate.getDomainEvents()) {
            log.debug("Publishing domain event: {}", event.getClass().getSimpleName());
            publisher.publishEvent(event);
        }
        aggregate.clearEvents();
    }

    public void publishEvent(DomainEvent event) {
        log.debug("Publishing domain event: {}", event.getClass().getSimpleName());
        publisher.publishEvent(event);
    }
}
