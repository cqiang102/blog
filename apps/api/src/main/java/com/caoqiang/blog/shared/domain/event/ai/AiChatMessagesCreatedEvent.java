package com.caoqiang.blog.shared.domain.event.ai;

import com.caoqiang.blog.shared.domain.model.DomainEvent;
import java.util.List;
import java.util.UUID;

public class AiChatMessagesCreatedEvent extends DomainEvent {

    private final List<UUID> messageIds;

    public AiChatMessagesCreatedEvent(List<UUID> messageIds) {
        this.messageIds = List.copyOf(messageIds);
    }

    public List<UUID> getMessageIds() {
        return messageIds;
    }
}
