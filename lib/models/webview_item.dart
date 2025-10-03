import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// ------------------------------------------------------------
/// WebView 模型：包裝 InAppWebView 狀態 + 前進/後退能力
/// ------------------------------------------------------------
class WebViewItem extends ChangeNotifier {
  final String id;
  String title;
  final String initialUrl;

  InAppWebViewController? controller;

  // 狀態
  String _currentUrl;
  bool _canGoBack = false;
  bool _canGoForward = false;

  // 本地歷史作為備援（避免某些平台/站點 canGoBack/Forward 不即時）
  final List<String> history = <String>[];
  int historyIndex = -1;

  WebViewItem({
    required this.id,
    required this.title,
    required String url,
  })  : initialUrl = url,
        _currentUrl = url {
    if (!_isAbout(url)) {
      history.add(url);
      historyIndex = 0;
    }
  }

  // 讀取
  String get currentUrl => _currentUrl;
  bool get canGoBack => _canGoBack;
  bool get canGoForward => _canGoForward;

  // 工具
  static bool _isAbout(String u) => u.startsWith('about:');

  void setController(InAppWebViewController c) {
    controller = c;
    notifyListeners();
  }

  void updateTitle(String? t) {
    if (t == null) return;
    title = t;
    notifyListeners();
  }

  void updateCurrentUrl(String u) {
    _currentUrl = u;

    // 同步到本地歷史
    if (!_isAbout(u)) {
      final isSame = historyIndex >= 0 && history[historyIndex] == u;
      if (!isSame) {
        if (historyIndex < history.length - 1) {
          history.removeRange(historyIndex + 1, history.length);
        }
        history.add(u);
        historyIndex = history.length - 1;
      }
    }
    notifyListeners();
  }

  Future<void> load(String u) async {
    _currentUrl = u;
    await controller?.loadUrl(urlRequest: URLRequest(url: WebUri(u)));

    // 先行寫入備援歷史，避免回/進失靈
    if (!_isAbout(u)) {
      if (historyIndex < history.length - 1) {
        history.removeRange(historyIndex + 1, history.length);
      }
      history.add(u);
      historyIndex = history.length - 1;
    }
    await refreshNavState();
    notifyListeners();
  }

  Future<void> back() async {
    if (await controller?.canGoBack() ?? false) {
      await controller?.goBack();
    } else if (historyIndex > 0) {
      // 備援：本地歷史回退
      historyIndex -= 1;
      final u = history[historyIndex];
      await controller?.loadUrl(urlRequest: URLRequest(url: WebUri(u)));
      _currentUrl = u;
    }
    await refreshNavState();
  }

  Future<void> forward() async {
    if (await controller?.canGoForward() ?? false) {
      await controller?.goForward();
    } else if (historyIndex >= 0 && historyIndex < history.length - 1) {
      // 備援：本地歷史前進
      historyIndex += 1;
      final u = history[historyIndex];
      await controller?.loadUrl(urlRequest: URLRequest(url: WebUri(u)));
      _currentUrl = u;
    }
    await refreshNavState();
  }

  Future<void> reload() async {
    await controller?.reload();
  }

  /// 與原生 webview 狀態對齊（同時考慮本地歷史作為補強）
  Future<void> refreshNavState() async {
    final b = await controller?.canGoBack() ?? false;
    final f = await controller?.canGoForward() ?? false;

    final hb = historyIndex > 0;
    final hf = historyIndex >= 0 && historyIndex < history.length - 1;

    final nextBack = b || hb;
    final nextForward = f || hf;

    if (_canGoBack != nextBack || _canGoForward != nextForward) {
      _canGoBack = nextBack;
      _canGoForward = nextForward;
      notifyListeners();
    }
  }

  // （可選）序列化：若你有把分頁持久化，就用這兩個
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'initialUrl': initialUrl,
    'currentUrl': _currentUrl,
    'history': history,
    'historyIndex': historyIndex,
  };

  factory WebViewItem.fromJson(Map<String, dynamic> json) {
    final item = WebViewItem(
      id: json['id'] as String,
      title: (json['title'] as String?) ?? '新分頁',
      url: (json['currentUrl'] as String?) ??
          (json['initialUrl'] as String? ?? 'about:blank'),
    );
    final his = (json['history'] as List?)?.cast<String>() ?? <String>[];
    final idx = (json['historyIndex'] as int?) ?? (his.isEmpty ? -1 : his.length - 1);
    if (his.isNotEmpty) {
      item.history
        ..clear()
        ..addAll(his);
      item.historyIndex = idx.clamp(-1, his.length - 1);
      item._currentUrl = item.history[item.historyIndex];
    }
    return item;
  }
}
