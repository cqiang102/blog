package com.caoqiang.blog.auth.application.event;

import com.caoqiang.blog.auth.event.UserCreatedEvent;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.context.event.EventListener;
import org.springframework.scheduling.annotation.Async;
import org.springframework.stereotype.Component;

/**
 * Owns auth-module reactions to newly created users.
 */
@Component
public class UserCreatedEventListener {

    private static final Logger log = LoggerFactory.getLogger(UserCreatedEventListener.class);

    @EventListener
    @Async
    public void onUserCreated(UserCreatedEvent event) {
        log.info("用户已创建: id={}", event.getUserId());
    }
}
