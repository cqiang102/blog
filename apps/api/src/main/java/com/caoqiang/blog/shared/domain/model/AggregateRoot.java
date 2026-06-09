package com.caoqiang.blog.shared.domain.model;

import jakarta.persistence.Id;
import jakarta.persistence.MappedSuperclass;
import jakarta.persistence.Transient;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;

@MappedSuperclass
public abstract class AggregateRoot {

    @Id
    @jakarta.persistence.Column(nullable = false, updatable = false)
    private UUID id = UUID.randomUUID();

    @Transient
    private final List<DomainEvent> domainEvents = new ArrayList<>();

    protected AggregateRoot() {
    }

    protected AggregateRoot(UUID id) {
        this.id = id;
    }

    public UUID getId() {
        return id;
    }

    protected void registerEvent(DomainEvent event) {
        domainEvents.add(event);
    }

    public List<DomainEvent> getDomainEvents() {
        return Collections.unmodifiableList(domainEvents);
    }

    public void clearEvents() {
        domainEvents.clear();
    }
}
