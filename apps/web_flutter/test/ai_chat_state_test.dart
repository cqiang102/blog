import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/features/about/application/ai_chat_controller.dart';

void main() {
  AiChatController controller(ProviderContainer container) {
    final provider = NotifierProvider<AiChatController, AiChatState>(
      AiChatController.new,
    );
    container.read(provider);
    return container.read(provider.notifier);
  }

  test('cancelSending removes an empty placeholder and unlocks input', () {
    final container = ProviderContainer.test();
    final chat = controller(container);

    chat.addUserMessage('hello');
    chat.cancelSending();

    expect(chat.state.isSending, isFalse);
    expect(chat.state.messages, hasLength(1));
    expect(chat.state.messages.single.isMine, isTrue);
  });

  test('cancelSending preserves partial streamed content', () {
    final container = ProviderContainer.test();
    final chat = controller(container);

    chat.addUserMessage('hello');
    chat.appendAiToken('partial');
    chat.cancelSending();

    expect(chat.state.isSending, isFalse);
    expect(chat.state.messages, hasLength(2));
    expect(chat.state.messages.last.text, 'partial');
  });

  test('completeAiReply replaces streamed draft with final answer', () {
    final container = ProviderContainer.test();
    final chat = controller(container);

    chat.addUserMessage('hello');
    chat.appendAiToken('1. first 2. second');
    chat.completeAiReply(
      sessionId: 'session-1',
      answer: '1. first\n2. second',
      remainingQuestions: 9,
      remainingMessages: 38,
    );

    expect(chat.state.isSending, isFalse);
    expect(chat.state.sessionId, 'session-1');
    expect(chat.state.messages.last.text, '1. first\n2. second');
  });
}
