package com.cn.aiztb.app.service.ai;

import java.lang.reflect.Field;
import java.lang.reflect.InvocationTargetException;
import java.lang.reflect.Method;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

import com.openai.client.OpenAIClientAsync;
import com.openai.core.JsonValue;
import com.openai.core.http.AsyncStreamResponse;
import com.openai.models.chat.completions.ChatCompletionChunk;
import com.openai.models.chat.completions.ChatCompletionCreateParams;
import com.openai.models.completions.CompletionUsage;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.ai.chat.messages.AssistantMessage;
import org.springframework.ai.chat.metadata.ChatGenerationMetadata;
import org.springframework.ai.chat.metadata.ChatResponseMetadata;
import org.springframework.ai.chat.metadata.DefaultUsage;
import org.springframework.ai.chat.metadata.Usage;
import org.springframework.ai.chat.model.ChatModel;
import org.springframework.ai.chat.model.ChatResponse;
import org.springframework.ai.chat.model.Generation;
import org.springframework.ai.chat.model.MessageAggregator;
import org.springframework.ai.chat.prompt.ChatOptions;
import org.springframework.ai.chat.prompt.Prompt;
import org.springframework.ai.model.tool.ToolCallingChatOptions;
import org.springframework.ai.openai.OpenAiChatModel;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;
import org.springframework.util.CollectionUtils;
import org.springframework.util.StringUtils;

import lombok.extern.slf4j.Slf4j;
import reactor.core.publisher.Flux;

/**
 * Temporary primary ChatModel for Spring AI versions where OpenAiChatModel
 * buffers no-tools streams before replaying them. Keep this compatibility patch
 * self-contained so it can be removed by deleting this file once Spring AI
 * provides true streaming natively.
 */
@Primary
@Component
@Slf4j
public class OpenAiChatModelStreamDecorator implements ChatModel {


    private final OpenAiChatModel delegate;

    private final OpenAiSdkStreamService streamService;

    public OpenAiChatModelStreamDecorator(@Qualifier("openAiChatModel") OpenAiChatModel delegate) {
        this.delegate = delegate;
        this.streamService = new OpenAiSdkStreamService(delegate);
    }

    @Override
    public ChatResponse call(Prompt prompt) {
        return delegate.call(prompt);
    }

    @Override
    public ChatOptions getDefaultOptions() {
        return delegate.getDefaultOptions();
    }

    @Override
    public Flux<ChatResponse> stream(Prompt prompt) {
        if (streamService.supportsDirectStream(prompt)) {
            log.debug("Using OpenAI SDK no-tools direct stream");
            return streamService.streamChatResponse(prompt);
        }
        log.debug("Delegating stream to Spring AI because prompt contains tools");
        return delegate.stream(prompt);
    }

    private static final class OpenAiSdkStreamService {

        private static final Logger log = LoggerFactory.getLogger(OpenAiSdkStreamService.class);

        private static final String REASONING_CONTENT_KEY = "reasoningContent";
        private static final String REASONING_CONTENT_SNAKE_KEY = "reasoning_content";
        private static final String REASONING_KEY = "reasoning";
        private static final String CHUNK_CHOICE_KEY = "chunkChoice";

        private final OpenAiChatModel openAiChatModel;

        private final Method createRequestMethod;

        private final OpenAIClientAsync openAiClientAsync;

        private OpenAiSdkStreamService(OpenAiChatModel openAiChatModel) {
            this.openAiChatModel = openAiChatModel;
            this.createRequestMethod = openCreateRequestMethod();
            this.openAiClientAsync = readAsyncClient(openAiChatModel);
        }

        private boolean supportsDirectStream(Prompt prompt) {
            return !(prompt.getOptions() instanceof ToolCallingChatOptions options)
                    || (CollectionUtils.isEmpty(options.getToolCallbacks())
                    && CollectionUtils.isEmpty(options.getToolNames()));
        }

        private Flux<ChatResponse> streamChatResponse(Prompt prompt) {
            if (!supportsDirectStream(prompt)) {
                throw new IllegalArgumentException("OpenAI SDK direct stream only supports no-tools prompts");
            }
            Flux<ChatResponse> chatResponses = Flux.defer(() -> {
                ChatCompletionCreateParams request = createStreamingRequest(prompt);
                ConcurrentHashMap<String, String> roleMap = new ConcurrentHashMap<>();
                log.debug("OpenAI SDK no-tools stream request: model={}", request.model().asString());
                return Flux.<ChatResponse>create(sink -> {
                    AsyncStreamResponse<ChatCompletionChunk> response =
                            openAiClientAsync.chat().completions().createStreaming(request);
                    sink.onCancel(response::close);
                    sink.onDispose(response::close);
                    response.subscribe(chunk -> {
                        try {
                            sink.next(toChatResponse(chunk, roleMap));
                        } catch (RuntimeException e) {
                            sink.error(e);
                        }
                    }).onCompleteFuture().whenComplete((unused, throwable) -> {
                        if (throwable != null) {
                            sink.error(throwable);
                        } else {
                            sink.complete();
                        }
                    });
                });
            });
            return new MessageAggregator().aggregate(chatResponses,
                    response -> log.debug("OpenAI SDK no-tools stream aggregated: {}", response.getMetadata()));
        }

        private Method openCreateRequestMethod() {
            try {
                Method method = OpenAiChatModel.class.getDeclaredMethod("createRequest", Prompt.class, boolean.class);
                method.setAccessible(true);
                return method;
            } catch (NoSuchMethodException e) {
                throw new IllegalStateException("Spring AI OpenAiChatModel.createRequest(Prompt, boolean) not found", e);
            }
        }

        private OpenAIClientAsync readAsyncClient(OpenAiChatModel model) {
            try {
                Field field = OpenAiChatModel.class.getDeclaredField("openAiClientAsync");
                field.setAccessible(true);
                return (OpenAIClientAsync) field.get(model);
            } catch (NoSuchFieldException | IllegalAccessException e) {
                throw new IllegalStateException("Spring AI OpenAiChatModel async client not available", e);
            }
        }

        private ChatCompletionCreateParams createStreamingRequest(Prompt prompt) {
            try {
                return (ChatCompletionCreateParams) createRequestMethod.invoke(openAiChatModel, prompt, true);
            } catch (IllegalAccessException e) {
                throw new IllegalStateException("Cannot access Spring AI OpenAiChatModel request builder", e);
            } catch (InvocationTargetException e) {
                Throwable target = e.getTargetException();
                if (target instanceof RuntimeException runtimeException) {
                    throw runtimeException;
                }
                throw new IllegalStateException("Spring AI OpenAiChatModel request builder failed", target);
            }
        }

        private ChatResponse toChatResponse(
                ChatCompletionChunk chunk,
                ConcurrentHashMap<String, String> roleMap) {

            ChatResponseMetadata metadata = responseMetadata(chunk);
            if (chunk._choices().isMissing() || chunk.choices().isEmpty()) {
                return new ChatResponse(List.of(), metadata);
            }

            List<Generation> generations = chunk.choices().stream()
                    .map(choice -> toGeneration(chunk, choice, roleMap))
                    .toList();
            return new ChatResponse(generations, metadata);
        }

        private ChatResponseMetadata responseMetadata(ChatCompletionChunk chunk) {
            ChatResponseMetadata.Builder builder = ChatResponseMetadata.builder()
                    .id(nullToEmpty(chunk.id()))
                    .model(nullToEmpty(chunk.model()));
            chunk.usage().ifPresent(usage -> builder.usage(toUsage(usage)));
            return builder.build();
        }

        private Usage toUsage(CompletionUsage usage) {
            Long cacheRead = usage.promptTokensDetails()
                    .flatMap(CompletionUsage.PromptTokensDetails::cachedTokens)
                    .orElse(null);
            return new DefaultUsage(
                    Math.toIntExact(usage.promptTokens()),
                    Math.toIntExact(usage.completionTokens()),
                    Math.toIntExact(usage.totalTokens()),
                    usage,
                    cacheRead,
                    null);
        }

        private Generation toGeneration(
                ChatCompletionChunk chunk,
                ChatCompletionChunk.Choice choice,
                ConcurrentHashMap<String, String> roleMap) {

            String role = choice.delta().role()
                    .map(ChatCompletionChunk.Choice.Delta.Role::asString)
                    .orElse(null);
            if (StringUtils.hasText(role)) {
                roleMap.put(chunk.id(), role);
            }

            String finishReason = choice.finishReason()
                    .map(ChatCompletionChunk.Choice.FinishReason::asString)
                    .orElse("");
            String content = choice.delta().content().orElse("");
            String reasoningContent = extractReasoningContent(choice);

            Map<String, Object> messageMetadata = new LinkedHashMap<>();
            messageMetadata.put("id", chunk.id());
            messageMetadata.put("role", roleMap.getOrDefault(chunk.id(), "assistant"));
            messageMetadata.put("index", choice.index());
            messageMetadata.put("finishReason", finishReason);
            messageMetadata.put(CHUNK_CHOICE_KEY, choice);
            if (StringUtils.hasText(reasoningContent)) {
                messageMetadata.put(REASONING_CONTENT_KEY, reasoningContent);
                messageMetadata.put(REASONING_CONTENT_SNAKE_KEY, reasoningContent);
            }

            AssistantMessage message = AssistantMessage.builder()
                    .content(content)
                    .properties(messageMetadata)
                    .build();
            ChatGenerationMetadata generationMetadata = ChatGenerationMetadata.builder()
                    .finishReason(finishReason)
                    .build();
            return new Generation(message, generationMetadata);
        }

        private String extractReasoningContent(ChatCompletionChunk.Choice choice) {
            Map<String, JsonValue> additionalProperties = choice.delta()._additionalProperties();
            JsonValue value = additionalProperties.get(REASONING_CONTENT_SNAKE_KEY);
            if (value == null) {
                value = additionalProperties.get(REASONING_CONTENT_KEY);
            }
            if (value == null) {
                value = additionalProperties.get(REASONING_KEY);
            }
            return jsonValueToString(value);
        }

        private String jsonValueToString(JsonValue value) {
            if (value == null || value.isMissing() || value.isNull()) {
                return "";
            }
            return value.accept(new JsonValue.Visitor<>() {
                @Override
                public String visitString(String value) {
                    return value;
                }

                @Override
                public String visitDefault() {
                    return value.toString();
                }
            });
        }

        private String nullToEmpty(String value) {
            return value == null ? "" : value;
        }
    }
}
