import 'package:flutter/foundation.dart';

import '../services/ai/ai_service.dart';
import '../services/ai/ai_types.dart';

/// Estado de chats de IA desacoplado de [VaultSession].
class VaultAiController extends ChangeNotifier {
  VaultAiController();

  AiService? _aiService;
  late List<AiChatThreadData> _threads;
  int _activeIndex = 0;

  AiService? get aiService => _aiService;
  bool get aiEnabled => _aiService != null;
  List<AiChatThreadData> get chatThreads => List.unmodifiable(_threads);
  int get activeChatIndex => _activeIndex;
  AiChatThreadData get activeChat => _threads[_activeIndex];

  void initializeThreads(List<AiChatThreadData> initial) {
    _threads = List<AiChatThreadData>.from(initial);
    _activeIndex = 0;
  }

  void loadFromPayload(List<AiChatThreadData> threads, int activeIndex) {
    _threads = List<AiChatThreadData>.from(threads);
    if (_threads.isEmpty) {
      _threads = [
        AiChatThreadData(id: 'chat_0', title: 'Chat 1', messages: const []),
      ];
    }
    _activeIndex = activeIndex.clamp(0, _threads.length - 1);
    notifyListeners();
  }

  List<AiChatThreadData> exportThreads() => List<AiChatThreadData>.from(_threads);

  int exportActiveIndex() => _activeIndex;

  void setAiService(AiService? service) {
    _aiService = service;
    notifyListeners();
  }

  void setActiveChatIndex(int index) {
    if (index < 0 || index >= _threads.length) return;
    _activeIndex = index;
    notifyListeners();
  }

  void replaceThreads(List<AiChatThreadData> threads, {int? activeIndex}) {
    _threads = List<AiChatThreadData>.from(threads);
    if (_threads.isEmpty) {
      _threads = [
        AiChatThreadData(id: 'chat_0', title: 'Chat 1', messages: const []),
      ];
    }
    _activeIndex = (activeIndex ?? _activeIndex).clamp(0, _threads.length - 1);
    notifyListeners();
  }
}
