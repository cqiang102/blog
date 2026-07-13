package com.caoqiang.blog.interaction.application.service;

import com.caoqiang.blog.content.application.api.ContentInteractionService;
import com.caoqiang.blog.content.application.api.ContentInteractionSnapshot;
import com.caoqiang.blog.shared.exception.BusinessException;
import com.caoqiang.blog.user.application.api.IdentityUser;
import com.caoqiang.blog.user.application.api.UserAccountService;
import java.util.Collection;
import java.util.Map;
import java.util.UUID;
import java.util.function.Function;
import java.util.stream.Collectors;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;

@Component
public class InteractionReferenceData {

    private final ContentInteractionService contentInteractionService;
    private final UserAccountService userAccountService;

    public InteractionReferenceData(
            ContentInteractionService contentInteractionService,
            UserAccountService userAccountService
    ) {
        this.contentInteractionService = contentInteractionService;
        this.userAccountService = userAccountService;
    }

    public Map<UUID, ContentInteractionSnapshot> contents(Collection<UUID> ids) {
        return contentInteractionService.findByIds(ids).stream().collect(Collectors.toMap(
                ContentInteractionSnapshot::id,
                Function.identity()
        ));
    }

    public Map<UUID, IdentityUser> users(Collection<UUID> ids) {
        return userAccountService.findByIds(ids).stream().collect(Collectors.toMap(
                IdentityUser::id,
                Function.identity()
        ));
    }

    public ContentInteractionSnapshot content(Map<UUID, ContentInteractionSnapshot> contents, UUID id) {
        ContentInteractionSnapshot content = contents.get(id);
        if (content == null) {
            throw new BusinessException(HttpStatus.INTERNAL_SERVER_ERROR, "互动记录关联的内容不存在");
        }
        return content;
    }

    public IdentityUser user(Map<UUID, IdentityUser> users, UUID id) {
        IdentityUser user = users.get(id);
        if (user == null) {
            throw new BusinessException(HttpStatus.INTERNAL_SERVER_ERROR, "互动记录关联的用户不存在");
        }
        return user;
    }

    public String avatarUrl(IdentityUser user) {
        return contentInteractionService.resolveMediaUrl(user.avatarUrl());
    }
}
