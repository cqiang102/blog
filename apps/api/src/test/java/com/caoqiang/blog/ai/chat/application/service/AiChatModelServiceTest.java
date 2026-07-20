package com.caoqiang.blog.ai.chat.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;

import com.caoqiang.blog.ai.chat.application.dto.AiChatHistoryMessage;
import com.caoqiang.blog.ai.chat.domain.model.AiMessageRole;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.ai.chat.client.ChatClient;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.messages.UserMessage;

class AiChatModelServiceTest {

    private final AiChatModelService service = new AiChatModelService(mock(ChatClient.class), mock(AiBlogTools.class));

    @Test
    void mapsBusinessHistoryToModelMessagesWithoutASecondMemoryStore() {
        var messages = service.toModelHistory(List.of(
                new AiChatHistoryMessage(AiMessageRole.USER, "问题"),
                new AiChatHistoryMessage(AiMessageRole.ASSISTANT, "回答")));

        assertThat(messages).hasSize(2);
        assertThat(messages.get(0)).isInstanceOf(UserMessage.class);
        assertThat(messages.get(0).getText()).isEqualTo("问题");
        assertThat(messages.get(1)).isInstanceOf(AssistantMessage.class);
        assertThat(messages.get(1).getText()).isEqualTo("回答");
    }

    @Test
    void rejectsRolesThatCannotBeReconstructedSafely() {
        var history = List.of(new AiChatHistoryMessage(AiMessageRole.TOOL, "opaque tool payload"));

        assertThatThrownBy(() -> service.toModelHistory(history))
                .isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("TOOL");
    }
}
