import 'dart:async';
import 'dart:convert';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:my_flutter_app/screens/settings.dart';
import 'package:my_flutter_app/screens/works_screen.dart';
import 'package:my_flutter_app/theme/app_theme.dart';
import 'package:my_flutter_app/localization/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:uuid/uuid.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class WebViewTab extends ChangeNotifier {
  final String id;
  final String title;
  String url;  // Make this mutable
  final WebviewController controller;
  final GlobalKey webViewKey = GlobalKey();
  bool isInitialized = false;
  bool isVisible = false;
  final List<String> history = [];
  int historyIndex = -1;
  LoadingState _loadingState = LoadingState.none;
  bool canGoBack = false;
  bool canGoForward = false;
  String _currentUrl = '';  // Track current URL
  
  String get currentUrl => _currentUrl;
  LoadingState get loadingState => _loadingState;
  
  set loadingState(LoadingState state) {
    if (_loadingState != state) {
      _loadingState = state;
      if (state == LoadingState.navigationCompleted) {
        isInitialized = true;
      }
      notifyListeners();
    }
  }
  
  // Update current URL and notify listeners
  void updateCurrentUrl(String newUrl) {
    if (_currentUrl != newUrl) {
      _currentUrl = newUrl;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    notifyListeners();
  }

  WebViewTab({
    required this.id,
    required this.title,
    required this.url,
    required this.controller,
  }) {
    // Listen to loading state changes
    controller.loadingState.listen((state) {
      loadingState = state;
    });
  }
}

class _HomeScreenState extends State<HomeScreen> {
  String selectedContact = '';
  bool showSettings = false;
  int _selectedIndex = 0;

  // Controllers for the new workspace dialog
  final _nameController = TextEditingController();
  final _urlController = TextEditingController();

  // Tab management
  final List<WebViewTab> _tabs = [];
  int _currentTabIndex = -1;

  // Fixed home page
  final Map<String, String> _fixedItems = {
    'Home': 'https://www.google.com',
  };

  // Map to store custom workspaces
  late Map<String, String> _customWorkspaces = {};
  final String _workspacesKey = 'saved_workspaces';

  // Combined navigation items (fixed + custom)
  Map<String, String> get _navItems {
    return {..._fixedItems, ..._customWorkspaces};
  }

  @override
  void initState() {
    super.initState();
    _loadWorkspaces();
  }

  // 從 SharedPreferences 載入工作區
  Future<void> _loadWorkspaces() async {
    final prefs = await SharedPreferences.getInstance();
    final workspacesJson = prefs.getString(_workspacesKey);

    setState(() {
      if (workspacesJson != null) {
        // 載入已儲存的工作區
        final decoded = Map<String, dynamic>.from(
            Map<String, dynamic>.from(jsonDecode(workspacesJson))
        );
        _customWorkspaces =
            decoded.map((key, value) => MapEntry(key, value.toString()));
      } else {
        _customWorkspaces = {};
      }

      // Open the first tab if none is open
      if (_tabs.isEmpty && _navItems.isNotEmpty) {
        final firstItem = _navItems.entries.first;
        _addNewTab(firstItem.key, firstItem.value);
      }
    });
  }

  // Save custom workspaces to SharedPreferences
  Future<void> _saveWorkspaces() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_workspacesKey, jsonEncode(_customWorkspaces));
  }

  @override
  void dispose() {
    // Dispose all web view controllers when the widget is disposed
    for (var tab in _tabs) {
      tab.controller.dispose();
    }
    super.dispose();
  }

  Future<void> _addNewTab(String title, String url) async {
    try {
      final controller = WebviewController();
      
      // 先創建分頁但不要立即顯示
      final newTab = WebViewTab(
        id: const Uuid().v4(),
        title: title,
        url: url,
        controller: controller,
      );

      // 先將分頁添加到列表（但保持不可見）
      if (mounted) {
        setState(() {
          _tabs.add(newTab);
          _currentTabIndex = _tabs.length - 1;
          // 先不設置 isVisible = true
        });
      }

      // 初始化控制器
      await controller.initialize();
      
      // 設置 URL 監聽器
      controller.url.listen((newUrl) {
        if (newTab.historyIndex == -1 || (newTab.history.isNotEmpty && newTab.history[newTab.historyIndex] != newUrl)) {
          if (newTab.historyIndex < newTab.history.length - 1) {
            newTab.history.removeRange(newTab.historyIndex + 1, newTab.history.length);
          }
          newTab.history.add(newUrl);
          newTab.historyIndex = newTab.history.length - 1;
        }

        // 更新 URL 和導航狀態
        newTab.updateCurrentUrl(newUrl);
        newTab.canGoBack = newTab.historyIndex > 0;
        newTab.canGoForward = newTab.historyIndex < newTab.history.length - 1;
        newTab.notifyListeners();
      });

      // 載入 URL 並等待完成
      await controller.loadUrl(url);
      
      // 確保控制器已準備好後再顯示
      if (mounted) {
        setState(() {
          newTab.isInitialized = true;
          newTab.isVisible = true;
        });
      }
    } catch (e) {
      debugPrint('Error creating web view: $e');
      if (mounted) {
        setState(() {
          _tabs.removeWhere((tab) => tab.title == title && tab.url == url);
          if (_currentTabIndex >= _tabs.length) {
            _currentTabIndex = _tabs.length - 1;
          }
        });
      }
    }
  }

  void _closeTab(int index) {
    setState(() {
      _tabs.removeAt(index);
      if (_currentTabIndex >= _tabs.length) {
        _currentTabIndex = _tabs.length - 1;
      }
    });
  }

  Future<void> _showAddWorkspaceDialog() async {
    _nameController.clear();
    _urlController.clear();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(context.tr('newWorkspace')),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.tr('workspaceNameLabel'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              TextBox(
                controller: _nameController,
                placeholder: context.tr('workspaceNameLabel'),
              ),
              const SizedBox(height: 12),
              Text(
                context.tr('workspaceUrlLabel'),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 4),
              TextBox(
                controller: _urlController,
                placeholder: 'https://example.com',
              ),
            ],
          ),
        ),
        actions: [
          Button(
            child: Text(context.tr('cancel')),
            onPressed: () => Navigator.pop(context, false),
          ),
          FilledButton(
            child: Text(context.tr('add')),
            onPressed: () {
              if (_nameController.text.isNotEmpty && _urlController.text.isNotEmpty) {
                Navigator.pop(context, true);
              }
            },
          ),
        ],
      ),
    );

    if (result == true) {
      // Add the new workspace to navigation items
      final name = _nameController.text;
      final url = _urlController.text;

      // Ensure URL has a scheme
      var finalUrl = url.trim();
      if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
        finalUrl = 'https://$finalUrl';
      }

      setState(() {
        _customWorkspaces[name] = finalUrl;
        // Save to SharedPreferences
        _saveWorkspaces();
        // Select the newly added workspace
        _selectedIndex = _navItems.length - 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();

    return Column(
      children: [
        Expanded(
          child: NavigationView(
            appBar: null,
            pane: NavigationPane(
              selected: _selectedIndex,
              onChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                  // 如果是設置頁面，顯示設置內容
                  if (index == _navItems.length) {
                    showSettings = true;
                  } else {
                    showSettings = false;
                    // 切換到對應的 tab
                    if (_tabs.isNotEmpty && index < _tabs.length) {
                      _currentTabIndex = index;
                    }
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
              size: const NavigationPaneSize(
                openMaxWidth: 250,
                openMinWidth: 200,
              ),
              header: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                alignment: Alignment.centerLeft,
                constraints: const BoxConstraints(minHeight: 40),
                child: Text(
                  context.tr('appTitle'),
                  style: FluentTheme.of(context).typography.bodyStrong?.copyWith(
                    color: FluentTheme.of(context).accentColor,
                  ),
                ),
              ),
              items: [
                // 首頁項目
                PaneItem(
                  icon: const Icon(FluentIcons.home),
                  title: Text(_fixedItems.keys.first),
                  body: _buildMainContent(),
                  onTap: () {
                    setState(() {
                      _selectedIndex = 0;
                      showSettings = false;
                    });
                  },
                ),
                // 工作區項目
                ..._customWorkspaces.entries.map<NavigationPaneItem>((entry) {
                  final title = entry.key;
                  final url = entry.value;
                  return PaneItem(
                    icon: const Icon(FluentIcons.globe),
                    title: Text(title),
                    body: WorksScreen(title: title, url: url),
                    onTap: () {
                      setState(() {
                        _selectedIndex = _navItems.keys.toList().indexOf(title);
                        showSettings = false;
                      });
                    },
                    trailing: IconButton(
                      icon: const Icon(FluentIcons.delete, size: 16),
                      style: ButtonStyle(
                        padding: WidgetStateProperty.all(EdgeInsets.zero),
                        iconSize: WidgetStateProperty.all(16),
                      ),
                      onPressed: () {
                        setState(() {
                          _customWorkspaces.remove(title);
                          _saveWorkspaces();
                          // If the deleted workspace was selected, go back to home
                          if (_selectedIndex > 0 &&
                              _selectedIndex < _navItems.length &&
                              _navItems.entries.elementAt(_selectedIndex).key == title) {
                            _selectedIndex = 0;
                          }
                        });
                        return;
                      },
                    ),
                  );
                }),
              ],
              footerItems: <NavigationPaneItem>[
                PaneItemAction(
                  icon: const Icon(FluentIcons.add),
                  title: Text(context.tr('newWorkspace')),
                  onTap: _showAddWorkspaceDialog,
                ),
                PaneItemSeparator(),
                PaneItem(
                  icon: const Icon(FluentIcons.settings),
                  title: Text(context.tr('settings')),
                  body: Settings(
                    onBackPressed: () => setState(() {
                      _selectedIndex = 0;
                      showSettings = false;
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        _buildTabBar(),

        if (_tabs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: ListenableBuilder(
              listenable: _tabs.isNotEmpty ? _tabs[_currentTabIndex] : ValueNotifier(null),
              builder: (context, _) {
                final currentTab = _tabs[_currentTabIndex];
                return SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(FluentIcons.back),
                          onPressed: currentTab.canGoBack
                              ? () {
                            if (currentTab.historyIndex > 0) {
                              currentTab.historyIndex--;
                              currentTab.controller.loadUrl(currentTab.history[currentTab.historyIndex]);
                              // Force update the navigation state
                              currentTab.canGoBack = currentTab.historyIndex > 0;
                              currentTab.canGoForward = currentTab.historyIndex < currentTab.history.length - 1;
                              currentTab.notifyListeners();
                            }
                          }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(FluentIcons.forward),
                          onPressed: currentTab.canGoForward
                              ? () {
                            if (currentTab.historyIndex < currentTab.history.length - 1) {
                              currentTab.historyIndex++;
                              currentTab.controller.loadUrl(currentTab.history[currentTab.historyIndex]);
                              // Force update the navigation state
                              currentTab.canGoBack = currentTab.historyIndex > 0;
                              currentTab.canGoForward = currentTab.historyIndex < currentTab.history.length - 1;
                              currentTab.notifyListeners();
                            }
                          }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(FluentIcons.refresh),
                          onPressed: () {
                            final controller = _tabs[_currentTabIndex].controller;
                            controller.reload();
                          },
                        ),
                        const SizedBox(width: 8),
                        // URL input field
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: ListenableBuilder(
                              listenable: _tabs[_currentTabIndex],
                              builder: (context, _) {
                                final currentTab = _tabs[_currentTabIndex];
                                final urlController = TextEditingController(text: currentTab.currentUrl);
                                
                                return TextBox(
                                  controller: urlController,
                                  placeholder: '輸入網址或搜尋關鍵字',
                                  onSubmitted: (value) async {
                                    if (value.isEmpty) return;
                                    
                                    String url = value.trim();
                                    
                                    // If it's a valid URL, navigate to it
                                    if (url.contains('.') && !url.contains(' ')) {
                                      // Add https:// if no protocol is specified
                                      if (!url.startsWith('http://') && !url.startsWith('https://')) {
                                        url = 'https://$url';
                                      }
                                      // Check if it's a valid URL
                                      try {
                                        final uri = Uri.parse(url);
                                        if (uri.host.isNotEmpty) {
                                          await currentTab.controller.loadUrl(url);
                                          return;
                                        }
                                      } catch (e) {
                                        // If URL parsing fails, treat as search
                                      }
                                    }
                                    
                                    // If not a valid URL or contains spaces, treat as search
                                    final searchQuery = Uri.encodeComponent(url);
                                    final searchUrl = 'https://www.google.com/search?q=$searchQuery';
                                    await currentTab.controller.loadUrl(searchUrl);
                                  },
                                  onTap: () {
                                    // Select all text when clicking on the TextBox
                                    urlController.selection = TextSelection(
                                      baseOffset: 0,
                                      extentOffset: urlController.text.length,
                                    );
                                  },
                                  prefix: const Padding(
                                    padding: EdgeInsets.only(left: 8.0, right: 8.0),
                                    child: Icon(FluentIcons.search, size: 16),
                                  ),
                                  suffix: currentTab.currentUrl.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(FluentIcons.clear, size: 16),
                                          onPressed: () {
                                            urlController.clear();
                                          },
                                        )
                                      : null,
                                );
                              },
                            ),
                          ),
                        )
                      ]
                  )
                  ,
                );
              },
            ),
          ),
        Expanded(
          child: _tabs.isEmpty
              ? const Center(child: Text('No tabs open. Click a navigation item to open a new tab.'))
              : _buildCurrentTab(),
        ),
      ],
    );
  }

  // 首頁分頁列
  // 新增分頁的方法
  void _addNewTabFromButton() {
    final newTabIndex = _tabs.length + 1;
    _addNewTab(
      '新分頁 $newTabIndex',
      'https://www.google.com',
    );
  }

  Widget _buildTabBar() {
    return Row(
      children: [
        Expanded(
          child: _buildTabBarContent(
            tabs: _tabs,
            currentIndex: _currentTabIndex,
            onTabSelected: (index) {
              setState(() {
                _currentTabIndex = index;
              });
            },
            onTabClosed: _closeTab,
          ),
        ),
        // 新增分頁按鈕
        Container(
          margin: const EdgeInsets.only(left: 8.0, right: 8.0),
          child: IconButton(
            icon: const Icon(FluentIcons.add, size: 16),
            style: ButtonStyle(
              iconSize: WidgetStateProperty.all(16),
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                return Colors.transparent;
              }),
            ),
            onPressed: _addNewTabFromButton,
          ),
        ),
      ],
    );
  }

  // 共用的分頁列 UI
  Widget _buildTabBarContent({
    required List<WebViewTab> tabs,
    required int currentIndex,
    required Function(int) onTabSelected,
    required Function(int) onTabClosed,
  }) {
    if (tabs.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 40,
      padding: const EdgeInsets.only(top: 6.0, left: 8.0, right: 8.0),
      color: Colors.grey[20],
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: tabs.length,
        itemBuilder: (context, index) {
          final tab = tabs[index];
          final isSelected = currentIndex == index;

          return ListenableBuilder(
            listenable: tab,
            builder: (context, _) {
              return Container(
                margin: const EdgeInsets.only(
                  right: 2.0,
                  top: 2.0,
                  bottom: 1.0,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.grey[30],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(6.0),
                    topRight: Radius.circular(6.0),
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(26),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    )
                  ] : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tab content area
                    SizedBox(
                      width: 120,
                      child: Button(
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.all(Colors.transparent),
                          padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 8.0)),
                          elevation: WidgetStateProperty.all(0),
                          shadowColor: WidgetStateProperty.all(Colors.transparent),
                          shape: WidgetStateProperty.all(RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4.0),
                            side: BorderSide.none,
                          )),
                        ),
                        onPressed: () => onTabSelected(index),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 16,
                              height: 16,
                              child: tab.loadingState == LoadingState.loading
                                  ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: ProgressRing(
                                  strokeWidth: 2.0,
                                  value: null,
                                ),
                              )
                                  : const Icon(FluentIcons.globe, size: 14),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                tab.title,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isSelected ? Colors.black : Colors.black.withAlpha(150),
                                  fontSize: 13,
                                  fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Close button
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: IconButton(
                        icon: Icon(
                          FluentIcons.chrome_close,
                          size: 14,
                          color: Colors.grey[130],
                        ),
                        onPressed: () => onTabClosed(index),
                        style: ButtonStyle(
                          padding: WidgetStateProperty.all(EdgeInsets.zero),
                          iconSize: WidgetStateProperty.all(14),
                          backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                            if (states.contains(WidgetState.hovered)) {
                              return Colors.grey[100];
                            }
                            return Colors.transparent;
                          }),
                          shape: WidgetStateProperty.all(const CircleBorder()),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildCurrentTab() {
    if (_currentTabIndex < 0 || _currentTabIndex >= _tabs.length) {
      return const Center(child: Text('No tab selected'));
    }

    final tab = _tabs[_currentTabIndex];

    return SizedBox.expand(
      child: Stack(
        children: [
          // WebView - Only show if the tab is marked as visible
          if (tab.isVisible)
            Positioned.fill(
              child: Webview(tab.controller),
            ),
        ],
      ),
    );
  }
}
