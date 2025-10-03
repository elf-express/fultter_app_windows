import 'dart:convert';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:my_flutter_app/widgets/keep_alive.dart';

// 依你的專案實際路徑調整
import 'package:my_flutter_app/theme/app_theme.dart';
import 'package:my_flutter_app/localization/app_localizations.dart';
import 'package:my_flutter_app/screens/settings.dart';
import '../models/webview_item.dart';
import 'home/home_area.dart';

/// ------------------------------------------------------------
/// HomeScreen（build = return NavigationView）
/// - Home 分頁持久化
/// - 工作區清單 + 各自最後網址持久化
/// ------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 左側選擇：0=Home；1..N=工作區；Settings 在 footer
  int _selectedIndex = 0;

  // Home tabs
  final List<WebViewItem> _homeTabs = [];
  int _currentHomeTab = 0;

  // 工作區（title -> lastUrl）
  final Map<String, String> _workspaces = {};

  // 新增工作區 dialog
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  static const _prefsHomeTabsKey = 'home_tabs_v2';
  static const _prefsWorkspacesKey = 'workspaces_v1'; // 新增：工作區持久化 key

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      _loadHomeTabs(),
      _loadWorkspaces(),
    ]);

    // 若 Home 沒有分頁，給一個預設
    if (_homeTabs.isEmpty) {
      _addHomeTab('新分頁 1', 'https://www.google.com', select: true);
    }
  }

  int get _settingsPaneIndex {
    // items: Home(1) + _workspaces.length
    final itemsCount = 1 + _workspaces.length;
    // footer: [PaneItemAction(新增工作區), PaneItemSeparator(), PaneItem(Settings)]
    // NavigationPane 的 index 會把這兩個也算進去，所以 +2 就是 Settings 的索引
    return itemsCount + 2;
  }

  // -------- 持久化：Home tabs --------
  Future<void> _loadHomeTabs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsHomeTabsKey);
      if (raw == null || raw.isEmpty) return;
      final list = (jsonDecode(raw) as List)
          .cast<Map<String, dynamic>>()
          .map((e) => WebViewItem(
        id: e['id'] as String,
        title: ((e['title'] as String?) ?? '').trim().isEmpty ? '新分頁' : e['title'] as String,
        url: ((e['url'] as String?) ?? '').isEmpty ? 'https://www.google.com' : e['url'] as String,
      ))
          .toList();
      setState(() {
        _homeTabs.addAll(list);
        _currentHomeTab = 0;
      });
    } catch (_) {}
  }

  Future<void> _saveHomeTabs() async {
    final prefs = await SharedPreferences.getInstance();
    final toSave = _homeTabs.map((e) => {'id': e.id, 'title': e.title, 'url': e.currentUrl}).toList();
    await prefs.setString(_prefsHomeTabsKey, jsonEncode(toSave));
  }

  void _addHomeTab(String title, String url, {bool select = true}) {
    setState(() {
      _homeTabs.add(WebViewItem(id: const Uuid().v4(), title: title, url: url));
      if (select) {
        _currentHomeTab = _homeTabs.length - 1;
        _selectedIndex = 0;
      }
    });
    _saveHomeTabs();
  }

  void _closeHomeTab(int index) {
    if (_homeTabs.length <= 1) return;
    setState(() {
      _homeTabs.removeAt(index);
      if (_currentHomeTab >= _homeTabs.length) _currentHomeTab = _homeTabs.length - 1;
    });
    _saveHomeTabs();
  }

  Widget _buildHomeWebView(WebViewItem item) {
    return InAppWebView(
      key: PageStorageKey(item.id),
      initialUrlRequest: URLRequest(url: WebUri(item.initialUrl)),

      onWebViewCreated: (controller) => {
        item.setController(controller)
      },
      onTitleChanged: (controller, t) => item.updateTitle(t),
      onLoadStart: (controller, url) async {
        item.updateCurrentUrl(url?.toString() ?? item.initialUrl);
        await item.refreshNavState();
      },
      onLoadStop: (controller, url) async {
        item.updateCurrentUrl(url?.toString() ?? item.initialUrl);
        await item.refreshNavState();
        _saveHomeTabs(); // 停止時保存
      },
      onProgressChanged: (controller, progress) async {
        if (progress == 100) await item.refreshNavState();
      },
    );
  }

  // -------- 持久化：Workspaces --------
  Future<void> _loadWorkspaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsWorkspacesKey);
      if (raw == null || raw.isEmpty) return;
      // 儲存成 Map<String,String>
      final map = Map<String, dynamic>.from(jsonDecode(raw));
      setState(() {
        _workspaces
          ..clear()
          ..addAll(map.map((k, v) => MapEntry(k, v.toString())));
      });
    } catch (_) {}
  }

  Future<void> _saveWorkspaces() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsWorkspacesKey, jsonEncode(_workspaces));
  }

  void _updateWorkspaceUrl(String title, String url) {
    if (_workspaces[title] == url) return;
    setState(() {
      _workspaces[title] = url;
    });
    _saveWorkspaces();
  }

  // 新增 / 刪除 工作區
  Future<void> _showAddWorkspaceDialog() async {
    _nameController.clear();
    _urlController.clear();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(context.tr('newWorkspace')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextBox(controller: _nameController, placeholder: 'Name'),
            const SizedBox(height: 8),
            TextBox(controller: _urlController, placeholder: 'https://example.com'),
          ],
        ),
        actions: [
          Button(child: Text(context.tr('cancel')), onPressed: () => Navigator.pop(context, false)),
          FilledButton(child: Text(context.tr('add')), onPressed: () => Navigator.pop(context, true)),
        ],
      ),
    );

    if (ok == true && _nameController.text.trim().isNotEmpty && _urlController.text.trim().isNotEmpty) {
      var u = _toNavigable(_urlController.text.trim());
      setState(() {
        _workspaces[_nameController.text.trim()] = u;
        _selectedIndex = 1 + _workspaces.keys.toList().indexOf(_nameController.text.trim());
      });
      _saveWorkspaces();
    }
  }

  void _removeWorkspace(String title) {
    setState(() {
      final idxInNav = 1 + _workspaces.keys.toList().indexOf(title);
      final wasSelected = _selectedIndex == idxInNav;
      _workspaces.remove(title);
      if (wasSelected) _selectedIndex = 0;
    });
    _saveWorkspaces();
  }

  String _toNavigable(String raw) {
    var u = raw.trim();
    if (!(u.startsWith('http://') || u.startsWith('https://'))) {
      if (u.contains(' ') || !u.contains('.')) {
        final q = Uri.encodeComponent(u);
        u = 'https://www.google.com/search?q=$q';
      } else {
        u = 'https://$u';
      }
    }
    return u;
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();

    // *** 佈局維持：直接 return NavigationView ***
    return NavigationView(
      appBar: null,
      pane: NavigationPane(
        selected: _selectedIndex,
        onChanged: (i) {
          setState(() {
            _selectedIndex = i;
            if (i != _settingsPaneIndex) {
            }
          });
        },
        displayMode: appTheme.displayMode,
        indicator: () {
          switch (appTheme.indicator) {
            case NavigationIndicators.sticky:
              return const StickyNavigationIndicator();
            case NavigationIndicators.end:
              return const EndNavigationIndicator();
          }
        }(),
        size: const NavigationPaneSize(openMinWidth: 200, openMaxWidth: 260),
        header: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            context.tr('appTitle'),
            style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
              color: FluentTheme.of(context).accentColor,
            ),
          ),
        ),
        items: [
          // Home
          PaneItem(
            icon: const Icon(FluentIcons.home),
            title: const Text('Home'),
            body: KeepAliveWrapper(
              child: HomeArea(
                tabs: _homeTabs,
                currentIndex: _currentHomeTab,
                onSelect: (i) {
                  setState(() {
                    _currentHomeTab = i.clamp(0, _homeTabs.length - 1);
                    _selectedIndex = 0;
                  });
                  _saveHomeTabs();
                },
                onAdd: () {
                  final newTitle = '新分頁 ${_homeTabs.length + 1}';
                  _addHomeTab(newTitle, 'https://www.google.com', select: true);
                },
                onClose: _closeHomeTab,
                buildWebView: _buildHomeWebView,
                onUrlSubmitted: (item, raw) async {
                  final u = _toNavigable(raw);
                  await item.load(u);
                },
              ),
            ),
          ),

          // 工作區（不顯示網址列；每個工作區最後網址會被記住）
          ..._workspaces.entries.map((e) {
            return PaneItem(
              icon: const Icon(FluentIcons.globe),
              title: Text(e.key),
              body: KeepAliveWrapper(
                child: WorkspaceArea(
                  title: e.key,
                  initialUrl: e.value,
                  onUrlChanged: (u) => _updateWorkspaceUrl(e.key, u), // ← 變更即寫回
                ),
              ),
              trailing: IconButton(
                icon: const Icon(FluentIcons.delete, size: 16),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => ContentDialog(
                      title: const Text('確認刪除'),
                      content: Text('確定要刪除工作區 "${e.key}" 嗎？此動作無法復原。'),
                      actions: [
                        Button(
                          child: const Text('取消'),
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        FilledButton(
                          child: const Text('刪除', style: TextStyle(color: Colors.white)),
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    if (mounted) {
                      _removeWorkspace(e.key);
                    }
                  }
                },
              ),
            );
          }),
        ],
        footerItems: [
          PaneItemAction(
            icon: const Icon(FluentIcons.add),
            title: Text(context.tr('newWorkspace')),
            onTap: _showAddWorkspaceDialog,
          ),
          PaneItemSeparator(),
          PaneItem(
            icon: const Icon(FluentIcons.settings),
            title: Text(context.tr('settings')),
            body: KeepAliveWrapper(
              child: Settings(
                onBack: () {
                  setState(() {
                    _selectedIndex = 0; // 固定返回到首頁
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------
/// WorkspaceArea：不顯示網址列，只顯示 上/下頁/重整；
/// 透過 onUrlChanged 回傳目前 URL 給上層做持久化。
/// ------------------------------------------------------------
class WorkspaceArea extends StatefulWidget {
  final String title;
  final String initialUrl;
  final ValueChanged<String>? onUrlChanged; // ← 新增：告知父層目前網址（持久化用）

  const WorkspaceArea({
    super.key,
    required this.title,
    required this.initialUrl,
    this.onUrlChanged,
  });

  @override
  State<WorkspaceArea> createState() => _WorkspaceAreaState();
}

class _WorkspaceAreaState extends State<WorkspaceArea> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  late final WebViewItem _item =
  WebViewItem(id: 'ws_${widget.title}', title: widget.title, url: widget.initialUrl);

  void _emitUrl(String? url) {
    final u = (url ?? _item.initialUrl);
    widget.onUrlChanged?.call(u);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Column(
      children: [
        AnimatedBuilder(
          animation: _item,
          builder: (context, _) {
            return Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.grey[10],
                border: Border(bottom: BorderSide(color: Colors.grey[60], width: 1)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                children: [
                  IconButton(icon: const Icon(FluentIcons.back), onPressed: _item.canGoBack ? () => _item.back() : null),
                  IconButton(icon: const Icon(FluentIcons.forward), onPressed: _item.canGoForward ? () => _item.forward() : null),
                  IconButton(icon: const Icon(FluentIcons.refresh), onPressed: () => _item.controller?.reload()),
                  const Spacer(),
                ],
              ),
            );
          },
        ),
        Expanded(child: _buildWebView(_item)),
      ],
    );
  }

  Widget _buildWebView(WebViewItem item) {
    return InAppWebView(
      key: PageStorageKey(item.id),
      initialUrlRequest: URLRequest(url: WebUri(item.initialUrl)),
      onWebViewCreated: (controller) => item.setController(controller),
      onTitleChanged: (controller, t) => item.updateTitle(t),
      onLoadStart: (controller, url) async {
        final u = url?.toString() ?? item.initialUrl;
        item.updateCurrentUrl(u);
        _emitUrl(u);               // 告知父層目前網址（即時更新）
        await item.refreshNavState();
      },
      onLoadStop: (controller, url) async {
        final u = url?.toString() ?? item.initialUrl;
        item.updateCurrentUrl(u);
        _emitUrl(u);               // 告知父層目前網址（確保停在此頁）
        await item.refreshNavState();
      },
      onProgressChanged: (controller, progress) async {
        if (progress == 100) await item.refreshNavState();
      },
    );
  }
}
