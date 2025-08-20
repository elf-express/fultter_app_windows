import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:provider/provider.dart';
import 'package:my_flutter_app/services/webview_manager.dart';

// 用於在 WorksWebView 和 WebViewManager 之間傳遞狀態更新的回調
typedef WebViewStateCallback = void Function(String url, bool isLoading);

// 導航狀態變更回調
typedef NavigationStateCallback = void Function(bool canGoBack, bool canGoForward);

class WorksWebView extends ChangeNotifier {
  final String initialUrl;
  WebviewController? _controller;
  bool _isInitialized = false;
  bool _isLoading = false;
  
  /// Safely access the controller, returns null if not initialized yet
  WebviewController? get controller => _controller;
  
  /// Check if the controller is ready to be used
  bool get isReady => _isInitialized && _controller != null;
  String get currentUrl => _webViewManager.getControllerUrl(initialUrl) ?? initialUrl;
  bool get isLoading => _isLoading;
  bool get canGoBack => _webViewManager.canGoBack(initialUrl);
  bool get canGoForward => _webViewManager.canGoForward(initialUrl);
  List<String> get history => _webViewManager.getHistory(initialUrl);
  int get historyIndex => _webViewManager.getHistoryIndex(initialUrl);
  
  final WebViewManager _webViewManager = WebViewManager();
  bool get isInitialized => _controller != null;
  
  // 用於在 WebViewManager 中更新狀態
  void _onStateUpdate(String url, bool isLoading) {
    if (isLoading != _isLoading) {
      _isLoading = isLoading;
      notifyListeners();
    }
  }
  
  // 處理導航狀態變更
  void _onNavigationStateUpdate(bool canGoBack, bool canGoForward) {
    // 通知監聽器導航狀態已變更
    notifyListeners();
  }

  WorksWebView({required this.initialUrl}) {
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      // 從 WebViewManager 獲取或創建 controller
      _controller = await _webViewManager.getController(
        initialUrl,
        onStateUpdate: _onStateUpdate,
      );
      
      // 添加導航狀態監聽器
      _webViewManager.addNavigationStateListener(
        initialUrl, 
        _onNavigationStateUpdate
      );
      
      // 標記為已初始化
      _isInitialized = true;
      
      // 如果 controller 已經初始化且當前 URL 不是初始 URL，則加載 URL
      if (_controller!.value.isInitialized && !_webViewManager.isControllerShowingUrl(initialUrl)) {
        await loadUrl(initialUrl);
      }
      
      // 通知監聽器初始化完成
      notifyListeners();
    } catch (e) {
      _isInitialized = false;
      debugPrint('初始化 WebView 錯誤: $e');
      rethrow;
    }
  }

  Future<void> loadUrl(String url) async {
    if (url.isEmpty || !_isInitialized || _controller == null) return;
    try {
      if (!url.startsWith('http')) url = 'https://$url';
      await _webViewManager.loadUrl(initialUrl, url);
    } catch (e) {
      debugPrint('載入 URL 錯誤: $e');
      rethrow;
    }
  }

  Future<void> goBack() async {
    await _webViewManager.goBack(initialUrl);
  }

  Future<void> goForward() async {
    await _webViewManager.goForward(initialUrl);
  }

  @override
  void dispose() {
    // 移除狀態監聽器
    _webViewManager.removeStateUpdateListener(initialUrl, _onStateUpdate);
    _webViewManager.removeNavigationStateListener(initialUrl, _onNavigationStateUpdate);
    
    // 標記為未初始化
    _isInitialized = false;
    // 移除對 controller 的引用
    _controller = null;
    
    super.dispose();
  }
}

class WorksScreen extends StatefulWidget {
  final String url;
  final String title;

  const WorksScreen({
    Key? key,
    required this.url,
    required this.title,
  }) : super(key: key);

  @override
  State<WorksScreen> createState() => _WorksScreenState();
}

class _WorksScreenState extends State<WorksScreen> {
  late final WorksWebView _webView;

  @override
  void initState() {
    super.initState();
    _webView = WorksWebView(initialUrl: widget.url);
  }

  @override
  void didUpdateWidget(WorksScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _webView.loadUrl(widget.url);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _webView,
      child: Consumer<WorksWebView>(
        builder: (context, webView, _) {
          // Show loading indicator if controller is not ready
          if (!webView.isReady) {
            return const Center(
              child: ProgressRing(),
            );
          }
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: FluentTheme.of(context).menuColor,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(FluentIcons.back, size: 16),
                      onPressed: webView.canGoBack ? webView.goBack : null,
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.forward, size: 16),
                      onPressed: webView.canGoForward ? webView.goForward : null,
                    ),
                    IconButton(
                      icon: const Icon(FluentIcons.refresh, size: 16),
                      onPressed: () => webView.loadUrl(webView.currentUrl),
                    ),
                    if (webView.isLoading)
                      const Padding(
                        padding: EdgeInsets.only(left: 8.0),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: ProgressRing(strokeWidth: 2.0),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    // WebView
                    if (webView.controller != null)
                      Webview(
                        webView.controller!,
                        permissionRequested: (url, permissionKind, isUserInitiated) {
                          // 允許所有權限請求
                          return Future.value(true as FutureOr<WebviewPermissionDecision>?);
                        },
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}