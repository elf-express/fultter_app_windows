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
  WebviewController? _controller;
  final String initialUrl;

  bool _isInitialized = false;
  bool _isLoading = false;
  String _currentUrl = '';
  
  /// Safely access the controller, returns null if not initialized yet
  WebviewController? get controller => _controller;
  
  /// Check if the controller is ready to be used
  bool get isReady => _isInitialized && _controller != null;
  String get currentUrl => _currentUrl;
  bool get isLoading => _isLoading;
  
  // 歷史記錄相關屬性
  final List<String> _history = [];
  int _historyIndex = -1;
  
  List<String> get history => List.unmodifiable(_history);
  int get historyIndex => _historyIndex;
  bool get canGoBack => _historyIndex > 0;
  bool get canGoForward => _historyIndex < _history.length - 1;
  
  bool get isInitialized => _controller != null;
  
  // 判斷是否應該將 URL 添加到歷史記錄
  bool _shouldAddToHistory(String newUrl) {
    if (_history.isEmpty) return true;
    
    final currentUrl = _history[_historyIndex];
    
    // 如果新 URL 與當前 URL 相同，不添加到歷史記錄
    if (newUrl == currentUrl) return false;
    
    // 解析 URL 以比較主機和路徑
    try {
      final currentUri = Uri.parse(currentUrl);
      final newUri = Uri.parse(newUrl);
      
      // 如果主機和路徑相同，可能是參數不同，不添加到歷史記錄
      if (currentUri.host == newUri.host && 
          currentUri.path == newUri.path) {
        return false;
      }
    } catch (e) {
      // 如果 URL 解析失敗，則添加為新條目
      return true;
    }
    
    return true;
  }
  
  // 更新當前 URL 並處理歷史記錄
  void _updateCurrentUrl(String newUrl) {
    if (newUrl.isEmpty) return;
    
    _currentUrl = newUrl;
    
    // 如果是第一個 URL 或者應該添加到歷史記錄
    if (_history.isEmpty || _shouldAddToHistory(newUrl)) {
      // 如果當前不在歷史記錄的末尾，則刪除後面的記錄
      if (_historyIndex < _history.length - 1) {
        _history.removeRange(_historyIndex + 1, _history.length);
      }
      
      _history.add(newUrl);
      _historyIndex = _history.length - 1;
    } else {
      // 更新當前歷史記錄條目
      _history[_historyIndex] = newUrl;
    }
    
    // 通知監聽器 URL 已更新
    notifyListeners();
  }
  
  // 導航到上一頁
  void goBack() {
    if (_historyIndex > 0) {
      _historyIndex--;
      _controller?.loadUrl(_history[_historyIndex]);
      notifyListeners();
    }
  }
  
  // 導航到下一頁
  void goForward() {
    if (_historyIndex < _history.length - 1) {
      _historyIndex++;
      _controller?.loadUrl(_history[_historyIndex]);
      notifyListeners();
    }
  }

  WorksWebView({required this.initialUrl}) {
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      _controller = WebviewController();
      
      // 初始化控制器
      await _controller?.initialize();
      
      // 設置 URL 監聽器
      _controller?.url.listen((newUrl) {
        if (newUrl != null && newUrl.isNotEmpty) {
          _updateCurrentUrl(newUrl);
        }
      });
      
      // 設置加載狀態監聽器
      _controller?.loadingState.listen((state) {
        _isLoading = state == LoadingState.loading;
        notifyListeners();
      });
      
      // 標記為已初始化
      _isInitialized = true;
      
      // 加載初始 URL
      await loadUrl(initialUrl);
      
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
      await _controller?.loadUrl(url);
    } catch (e) {
      debugPrint('載入 URL 錯誤: $e');
      rethrow;
    }
  }

  // goBack 和 goForward 方法已經在類的頂部實現

  @override
  void dispose() {
    // 標記為未初始化
    _isInitialized = false;
    
    // 釋放 controller 資源
    _controller?.dispose();
    _controller = null;
    
    // 清空歷史記錄
    _history.clear();
    _historyIndex = -1;
    
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