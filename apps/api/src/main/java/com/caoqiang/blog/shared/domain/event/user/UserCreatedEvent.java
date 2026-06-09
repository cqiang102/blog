package com.caoqiang.blog.shared.domain.event.user;

import com.caoqiang.blog.shared.domain.model.DomainEvent;
import java.util.UUID;

public class UserCreatedEvent extends DomainEvent {

    private final UUID userId;
    private final String email;
    private final String nickname;

    public UserCreatedEvent(UUID userId, String email, String nickname) {
        this.userId = userId;
        this.email = email;
        this.nickname = nickname;
    }

    public UUID getUserId() {
        return userId;
    }

    public String getEmail() {
        return email;
    }

    public String getNickname() {
        return nickname;
    }
}
