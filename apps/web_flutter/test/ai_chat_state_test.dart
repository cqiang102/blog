import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_blog_web/src/auth/auth_controller.dart';
import 'package:personal_blog_web/src/core/api_client.dart';
import 'package:personal_blog_web/src/core/models.dart';
import 'package:personal_blog_web/src/core/sse/sse_event.dart';
import 'package:personal_blog_web/src/features/about/application/ai_chat_controller.dart';
import 'package:personal_blog_web/src/state/state.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AuthenticatedController extends AuthController {
  _AuthenticatedController(super.apiClient);

  @override
  String? get accessToken => 'token';

  @override
  Future<String?> getValidAccessToken() async => 'token';
}

class _ControllableAiApi extends BlogApiClient {
  _ControllableAiApi() : super(dio: Dio(), baseUrl: 'http://ai.test/api/v1');

  final events = StreamController<SseEvent>();
  final deleteStarted = Completer<void>();
  final releaseDelete = Completer<void>();

  @override
  Stream<SseEvent> sendAiMessageStream({
    required String accessToken,
    required String message,
    String? sessionId,
  }) => events.stream;

  @override
  Future<void> deleteAiSession({
    required String accessToken,
    required String sessionId,
  }) async {
    deleteStarted.complete();
    await releaseDelete.future;
  }
}

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

  test(
    'a slower history response cannot overwrite the latest session',
    () async {
      SharedPreferences.setMockInitialValues({});
      final slowStarted = Completer<void>();
      final releaseSlow = Completer<void>();
      final dio = Dio();
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) async {
            if (options.path.endsWith('/slow/messages')) {
              slowStarted.complete();
              await releaseSlow.future;
            }
            final sessionId = options.path.contains('/slow/') ? 'slow' : 'fast';
            handler.resolve(
              Response<Object?>(
                requestOptions: options,
                statusCode: 200,
                data: {
                  'success': true,
                  'data': {
                    'items': [
                      {
                        'id': '$sessionId-message',
                        'role': 'ASSISTANT',
                        'content': sessionId,
                        'createdAt': '2026-07-16T00:00:00Z',
                      },
                    ],
                    'page': 0,
                    'size': 50,
                    'total': 1,
                  },
                },
              ),
            );
          },
        ),
      );
      final api = BlogApiClient(dio: dio, baseUrl: 'http://ai.test/api/v1');
      final auth = AuthController(api);
      addTearDown(auth.dispose);
      await auth.loginWithSession(
        AuthSession(
          accessToken: 'token',
          expiresAt: DateTime.utc(2027),
          user: const UserProfile(
            id: 'user-1',
            email: 'user@example.com',
            nickname: 'User',
            role: 'USER',
          ),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authControllerProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);
      final chat = controller(container);

      final slow = chat.loadHistory('slow');
      await slowStarted.future;
      final fast = chat.loadHistory('fast');
      await fast;
      releaseSlow.complete();
      await slow;

      expect(chat.state.sessionId, 'fast');
      expect(chat.state.messages.single.text, 'fast');
      expect(chat.state.isLoadingHistory, isFalse);
    },
  );

  test(
    'deleting the current session cancels late token and done events',
    () async {
      final api = _ControllableAiApi();
      addTearDown(() async {
        if (!api.events.isClosed) await api.events.close();
      });
      final auth = _AuthenticatedController(api);
      addTearDown(auth.dispose);
      final container = ProviderContainer(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          authControllerProvider.overrideWithValue(auth),
        ],
      );
      addTearDown(container.dispose);
      final chat = controller(container);
      chat.addUserMessage('seed');
      chat.completeAiReply(
        sessionId: 'session-1',
        answer: 'seed answer',
        remainingQuestions: 9,
        remainingMessages: 38,
      );

      expect(await chat.send('next question'), AiChatSendOutcome.started);
      expect(api.events.hasListener, isTrue);

      final deleting = chat.deleteSession('session-1');
      await api.deleteStarted.future;
      expect(api.events.hasListener, isFalse);
      final messagesAfterCancellation = chat.state.messages
          .map((message) => message.text)
          .toList();

      api.events.add(const SseEvent('token', 'late token'));
      api.events.add(
        SseEvent(
          'done',
          jsonEncode({
            'sessionId': 'session-1',
            'answer': 'late answer',
            'remainingQuestions': 8,
            'remainingMessages': 36,
          }),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        chat.state.messages.map((message) => message.text),
        messagesAfterCancellation,
      );

      api.releaseDelete.complete();
      await deleting;

      expect(chat.state.sessionId, isNull);
      expect(chat.state.messages, isEmpty);
      expect(chat.state.isSending, isFalse);
    },
  );
}
