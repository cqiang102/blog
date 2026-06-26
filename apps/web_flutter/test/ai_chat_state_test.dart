import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/state/ai_chat_state.dart';

void main() {
  test('cancelSending removes an empty placeholder and unlocks input', () {
    final notifier = AiChatNotifier();

    notifier.addUserMessage('hello');
    notifier.cancelSending();

    expect(notifier.state.isSending, isFalse);
    expect(notifier.state.messages, hasLength(1));
    expect(notifier.state.messages.single.isMine, isTrue);
  });

  test('cancelSending preserves partial streamed content', () {
    final notifier = AiChatNotifier();

    notifier.addUserMessage('hello');
    notifier.appendAiToken('partial');
    notifier.cancelSending();

    expect(notifier.state.isSending, isFalse);
    expect(notifier.state.messages, hasLength(2));
    expect(notifier.state.messages.last.text, 'partial');
  });

  test('completeAiReply replaces streamed draft with final answer', () {
    final notifier = AiChatNotifier();

    notifier.addUserMessage('hello');
    notifier.appendAiToken('1. first 2. second');
    notifier.completeAiReply(
      sessionId: 'session-1',
      answer: '1. first\n2. second',
      remainingQuestions: 9,
      remainingMessages: 38,
    );

    expect(notifier.state.isSending, isFalse);
    expect(notifier.state.sessionId, 'session-1');
    expect(notifier.state.messages.last.text, '1. first\n2. second');
  });
}
