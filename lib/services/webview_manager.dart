import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:webview_windows/webview_windows.dart';

import '../screens/works_screen.dart';

/// 導航狀態類，封裝與導航相關的狀態
class _NavigationState {
  final List<String> history = [];
  int historyIndex = -1;
  bool get canGoBack => historyIndex > 0;
  bool get canGoForward => historyIndex < history.length - 1;
  String? get currentUrl => historyIndex >= 0 && historyIndex < history.length 
      ? history[historyIndex] 
      : null;

  /// 更新歷史記錄
  void updateHistory(String url) {
    // 如果是初始狀態，添加第一個 URL
    if (history.isEmpty) {
      history.add(url);
      historyIndex = 0;
    } 
    // 如果是新 URL 且不是當前歷史記錄中的 URL
    else if (url != history[historyIndex]) {
      // 如果在歷史記錄中間，則移除後面的項目
      if (historyIndex < history.length - 1) {
        history.removeRange(historyIndex + 1, history.length);
      }
      // 添加新 URL 到歷史記錄
      history.add(url);
      historyIndex++;
    }
  }

  /// 導航到上一頁
  String? goBack() {
    if (!canGoBack) return null;
    historyIndex--;
    return history[historyIndex];
  }

  /// 導航到下一頁
  String? goForward() {
    if (!canGoForward) return null;
    historyIndex++;
    return history[historyIndex];
  }

  /// 清除歷史記錄
  void clear() {
    final current = currentUrl;
    history.clear();
    historyIndex = -1;
    if (current != null) {
      history.add(current);
      historyIndex = 0;
    }
  }
}

/// 導航狀態變更回調
typedef NavigationStateCallback = void Function(bool canGoBack, bool canGoForward);

class _ControllerWrapper {
  final WebviewController controller;
  bool _isInitialized = false;
  final List<WebViewStateCallback> _stateUpdateListeners = [];
  final List<NavigationStateCallback> _navStateListeners = [];
  final _NavigationState _navState = _NavigationState();
  String _currentUrl = '';
  bool _isLoading = false;
  StreamSubscription<String>? _urlSubscription;
  StreamSubscription<LoadingState>? _loadingSubscription;
  
  bool get canGoBack => _navState.canGoBack;
  bool get canGoForward => _navState.canGoForward;
  List<String> get history => List.unmodifiable(_navState.history);
  int get historyIndex => _navState.historyIndex;

  _ControllerWrapper(this.controller);

  Future<void> initialize() async {
    if (!_isInitialized) {
      await controller.initialize();

      // 監聽 URL 變化 - 確保只訂閱一次
      if (_urlSubscription == null) {
        _urlSubscription = controller.url.listen((url) {
          if (url.isNotEmpty) {
            _currentUrl = url;
            // 更新導航狀態
            _navState.updateHistory(url);
            _notifyStateUpdate();
          }
        });
      }

      // 監聽加載狀態 - 確保只訂閱一次
      if (_loadingSubscription == null) {
        _loadingSubscription = controller.loadingState.listen((state) {
          _isLoading = state == LoadingState.loading;
          _notifyStateUpdate();
        });
      }

      _isInitialized = true;
    }
  }

  void addStateUpdateListener(WebViewStateCallback listener) {
    if (!_stateUpdateListeners.contains(listener)) {
      _stateUpdateListeners.add(listener);
      // 立即通知當前狀態
      listener(_currentUrl, _isLoading);
    }
  }

  void removeStateUpdateListener(WebViewStateCallback listener) {
    _stateUpdateListeners.remove(listener);
  }

  void _notifyStateUpdate() {
    // Notify URL and loading state listeners
    for (final listener in List<WebViewStateCallback>.from(_stateUpdateListeners)) {
      listener(_currentUrl, _isLoading);
    }
    
    // Notify navigation state listeners
    _notifyNavStateUpdate();
  }
  
  void _notifyNavStateUpdate() {
    for (final listener in List<NavigationStateCallback>.from(_navStateListeners)) {
      listener(canGoBack, canGoForward);
    }
  }
  
  void addNavStateListener(NavigationStateCallback listener) {
    if (!_navStateListeners.contains(listener)) {
      _navStateListeners.add(listener);
      // Immediately notify the current state
      listener(canGoBack, canGoForward);
    }
  }
  
  void removeNavStateListener(NavigationStateCallback listener) {
    _navStateListeners.remove(listener);
  }
  
  /// 導航到上一頁
  Future<bool> goBack() async {
    final url = _navState.goBack();
    if (url != null) {
      await controller.loadUrl(url);
      _notifyNavStateUpdate();
      return true;
    }
    return false;
  }
  
  /// 導航到下一頁
  Future<bool> goForward() async {
    final url = _navState.goForward();
    if (url != null) {
      await controller.loadUrl(url);
      _notifyNavStateUpdate();
      return true;
    }
    return false;
  }
  
  /// 載入 URL 並更新導航狀態
  Future<void> loadUrl(String url) async {
    _navState.updateHistory(url);
    await controller.loadUrl(url);
    _notifyNavStateUpdate();
  }

  bool get isInitialized => _isInitialized;
  String get currentUrl => _currentUrl;

  Future<void> dispose() async {
    _stateUpdateListeners.clear();
    _navStateListeners.clear();
    await _urlSubscription?.cancel();
    await _loadingSubscription?.cancel();
    _urlSubscription = null;
    _loadingSubscription = null;
  }
}

class WebViewManager {
  static final WebViewManager _instance = WebViewManager._internal();
  final Map<String, _ControllerWrapper> _controllerWrappers = {};
  final Map<String, String> _currentUrls = {}; // Track current URL for each controller
  
  /// 獲取導航狀態
  bool canGoBack(String url) => _controllerWrappers[url]?.canGoBack ?? false;
  bool canGoForward(String url) => _controllerWrappers[url]?.canGoForward ?? false;
  List<String> getHistory(String url) => _controllerWrappers[url]?.history ?? [];
  int getHistoryIndex(String url) => _controllerWrappers[url]?.historyIndex ?? -1;
  
  /// 獲取控制器的當前 URL
  String? getControllerUrl(String url) => _controllerWrappers[url]?.currentUrl;

  factory WebViewManager() {
    return _instance;
  }

  WebViewManager._internal();

  Future<WebviewController> getController(
    String url, {
    WebViewStateCallback? onStateUpdate,
  }) async {
    // Check if we already have a controller for this URL
    if (_controllerWrappers.containsKey(url)) {
      final wrapper = _controllerWrappers[url]!;
      if (!wrapper.isInitialized) {
        await wrapper.initialize();
      }
      // Add the state update listener if provided
      if (onStateUpdate != null) {
        wrapper.addStateUpdateListener(onStateUpdate);
      }
      return wrapper.controller;
    }

    // Create a new controller
    final controller = WebviewController();
    final wrapper = _ControllerWrapper(controller);

    try {
      // Initialize the controller
      await wrapper.initialize();

      // Set up the controller
      _controllerWrappers[url] = wrapper;
      _currentUrls[url] = url;

      // Add state update listener
      if (onStateUpdate != null) {
        wrapper.addStateUpdateListener(onStateUpdate);
      }

      // Load the initial URL
      await controller.loadUrl(url);

      return wrapper.controller;
    } catch (e) {
      // Clean up on error
      await _cleanupController(url);
      debugPrint('Error initializing WebView: $e');
      rethrow;
    }
  }

  // Check if a controller is already showing a specific URL
  bool isControllerShowingUrl(String url) {
    return _currentUrls[url] == url;
  }

  // Get a controller by URL if it exists
  WebviewController? getExistingController(String url) {
    return _controllerWrappers[url]?.controller;
  }

  /// 添加狀態更新監聽器
  void addStateUpdateListener(String url, WebViewStateCallback listener) {
    final wrapper = _controllerWrappers[url];
    if (wrapper != null) {
      wrapper.addStateUpdateListener(listener);
    }
  }

  /// 移除狀態更新監聽器
  void removeStateUpdateListener(String url, WebViewStateCallback listener) {
    final wrapper = _controllerWrappers[url];
    if (wrapper != null) {
      wrapper.removeStateUpdateListener(listener);
    }
  }
  
  /// 添加導航狀態監聽器
  void addNavigationStateListener(String url, NavigationStateCallback listener) {
    final wrapper = _controllerWrappers[url];
    if (wrapper != null) {
      wrapper.addNavStateListener(listener);
    }
  }
  
  /// 移除導航狀態監聽器
  void removeNavigationStateListener(String url, NavigationStateCallback listener) {
    final wrapper = _controllerWrappers[url];
    if (wrapper != null) {
      wrapper.removeNavStateListener(listener);
    }
  }
  
  /// 導航到上一頁
  Future<bool> goBack(String url) async {
    final wrapper = _controllerWrappers[url];
    if (wrapper != null) {
      return await wrapper.goBack();
    }
    return false;
  }
  
  /// 導航到下一頁
  Future<bool> goForward(String url) async {
    final wrapper = _controllerWrappers[url];
    if (wrapper != null) {
      return await wrapper.goForward();
    }
    return false;
  }
  
  /// 載入 URL 並更新導航狀態
  Future<void> loadUrl(String controllerUrl, String url) async {
    final wrapper = _controllerWrappers[controllerUrl];
    if (wrapper != null) {
      await wrapper.loadUrl(url);
    }
  }

  Future<void> _cleanupController(String url) async {
    // Remove from maps
    _currentUrls.remove(url);

    // Dispose the wrapper (which will clean up its subscriptions)
    final wrapper = _controllerWrappers.remove(url);
    if (wrapper != null) {
      await wrapper.dispose();
    }
  }

  Future<void> dispose() async {
    // Dispose all controllers
    for (final wrapper in _controllerWrappers.values) {
      await wrapper.dispose();
    }
    _controllerWrappers.clear();
    _currentUrls.clear();
  }
}
