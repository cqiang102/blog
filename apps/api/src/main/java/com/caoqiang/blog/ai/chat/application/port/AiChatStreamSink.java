package com.caoqiang.blog.ai.chat.application.port;

import com.caoqiang.blog.ai.chat.application.dto.AiChatResponse;

/** Transport-neutral sink for a streaming AI response. */
public interface AiChatStreamSink {

    /** Returns false when the client can no longer receive data. */
    boolean emitToken(String token);

    void complete(AiChatResponse response);

    void fail(String message);

    /** Registers the callback invoked when the client disconnects or the transport times out. */
    void registerCancellation(Runnable callback);
}
