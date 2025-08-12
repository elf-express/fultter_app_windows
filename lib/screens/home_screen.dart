import 'dart:async';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:my_flutter_app/screens/settings.dart';
import 'package:my_flutter_app/theme/app_theme.dart';
import 'package:my_flutter_app/localization/app_localizations.dart';
import 'package:provider/provider.dart';
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
  var _orientation = 'landscape';
  var _iconSize = 'medium_icons';
  String selectedContact = '';
  bool showSettings = false;
  int _selectedIndex = 0;

  // Tab management
  final List<WebViewTab> _tabs = [];
  int _currentTabIndex = -1;
  final _uuid = const Uuid();

  // Map to store navigation items and their corresponding URLs
  Map<String, String> get _navItems {
    return {
      context.tr('home'): 'https://www.google.com',
      context.tr('news'): 'https://lowcode.my851.com/login?redirect=/home',
      context.tr('weather'): 'https://www.accuweather.com',
    };
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

      // Initialize the controller first
      await controller.initialize();
      await controller.loadUrl(url);

      // Create the tab with the initialized controller
      final newTab = WebViewTab(
        id: _uuid.v4(),
        title: title,
        url: url,
        controller: controller,
      );

      // Listen to URL changes and update history and current URL
      controller.url.listen((newUrl) {
        if (newTab.historyIndex == -1 || (newTab.history.isNotEmpty && newTab.history[newTab.historyIndex] != newUrl)) {
          if (newTab.historyIndex < newTab.history.length - 1) {
            newTab.history.removeRange(newTab.historyIndex + 1, newTab.history.length);
          }
          newTab.history.add(newUrl);
          newTab.historyIndex = newTab.history.length - 1;
        }

        // Update current URL and navigation state
        newTab.updateCurrentUrl(newUrl);
        newTab.canGoBack = newTab.historyIndex > 0;
        newTab.canGoForward = newTab.historyIndex < newTab.history.length - 1;
        newTab.notifyListeners();
      });

      // Add the tab to the list
      setState(() {
        _tabs.add(newTab);
        _currentTabIndex = _tabs.length - 1;
      });

      // Mark the tab as visible after a small delay to ensure the widget is built
      await Future.delayed(const Duration(milliseconds: 50));

      if (mounted) {
        setState(() {
          newTab.isVisible = true;
        });

        // Load the URL
        if (_tabs.contains(newTab)) {
          try {
            await controller.loadUrl(url);
          } catch (e) {
            debugPrint('Error loading URL: $e');
          }
        }
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
    if (_tabs.isNotEmpty && index >= 0 && index < _tabs.length) {
      final tabToRemove = _tabs[index];
      tabToRemove.controller.dispose();

      setState(() {
        _tabs.removeAt(index);
        if (_currentTabIndex >= _tabs.length) {
          _currentTabIndex = _tabs.length - 1;
        }
        if (_currentTabIndex < 0 && _tabs.isNotEmpty) {
          _currentTabIndex = 0;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();

    return Column(
      children: [
        // MenuBar at the very top of the window
        _buildMenuBar(),
        // Main content area with NavigationView
        Expanded(
          child: NavigationView(
            appBar: null,
            pane: NavigationPane(
              selected: _selectedIndex,
              onChanged: (index) {
                setState(() {
                  _selectedIndex = index;
                  showSettings = index == 1;
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
              items: _navItems.entries.map<NavigationPaneItem>((entry) {
                final title = entry.key;
                final url = entry.value;
                return PaneItem(
                  icon: const Icon(FluentIcons.globe),
                  title: Text(title),
                  body: _buildMainContent(),
                  onTap: () => _addNewTab('$title ${_tabs.where((t) => t.title.startsWith(title.split(' ')[0])).length + 1}', url),
                );
              }).toList(),
              footerItems: <NavigationPaneItem>[
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

  Widget _buildMenuBar() {
    return Container(
        color: FluentTheme.of(context).menuColor,
        child: MenuBar(
          items: [
            MenuBarItem(title: 'File', items: [
              MenuFlyoutSubItem(
                text: const Text('New'),
                items: (context) {
                  return [
                    MenuFlyoutItem(
                      text: const Text('Plain Text Documents'),
                      onPressed: () {},
                    ),
                    MenuFlyoutItem(
                      text: const Text('Rich Text Documents'),
                      onPressed: () {},
                    ),
                    MenuFlyoutItem(
                      text: const Text('Other Formats'),
                      onPressed: () {},
                    ),
                  ];
                },
              ),
              MenuFlyoutItem(text: const Text('Open'), onPressed: () {}),
              MenuFlyoutItem(text: const Text('Save'), onPressed: () {}),
              const MenuFlyoutSeparator(),
              MenuFlyoutItem(text: const Text('Exit'), onPressed: () {}),
            ]),
            MenuBarItem(title: 'Edit', items: [
              MenuFlyoutItem(text: const Text('Undo'), onPressed: () {}),
              MenuFlyoutItem(text: const Text('Cut'), onPressed: () {}),
              MenuFlyoutItem(text: const Text('Copy'), onPressed: () {}),
              MenuFlyoutItem(text: const Text('Paste'), onPressed: () {}),
            ]),
            MenuBarItem(title: 'View', items: [
              MenuFlyoutItem(text: const Text('Output'), onPressed: () {}),
              const MenuFlyoutSeparator(),
              RadioMenuFlyoutItem<String>(
                text: const Text('Landscape'),
                value: 'landscape',
                groupValue: _orientation,
                onChanged: (v) => setState(() => _orientation = v),
              ),
              RadioMenuFlyoutItem<String>(
                text: const Text('Portrait'),
                value: 'portrait',
                groupValue: _orientation,
                onChanged: (v) => setState(() => _orientation = v),
              ),
              const MenuFlyoutSeparator(),
              RadioMenuFlyoutItem<String>(
                text: const Text('Small icons'),
                value: 'small_icons',
                groupValue: _iconSize,
                onChanged: (v) => setState(() => _iconSize = v),
              ),
              RadioMenuFlyoutItem<String>(
                text: const Text('Medium icons'),
                value: 'medium_icons',
                groupValue: _iconSize,
                onChanged: (v) => setState(() => _iconSize = v),
              ),
              RadioMenuFlyoutItem<String>(
                text: const Text('Large icons'),
                value: 'large_icons',
                groupValue: _iconSize,
                onChanged: (v) => setState(() => _iconSize = v),
              ),
            ]),
            MenuBarItem(title: 'Help', items: [
              MenuFlyoutItem(text: const Text('About'), onPressed: () {}),
            ]),
          ],
        ));
  }

  // Check if the URL is from Google
  bool _isGoogleUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    try {
      final uri = Uri.parse(url);
      final host = uri.host.toLowerCase();
      return host.endsWith('google.com') || 
             host.endsWith('google.com.tw') ||
             host.endsWith('google.com.hk') ||
             host == 'google';
    } catch (e) {
      return false;
    }
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        if (_tabs.isNotEmpty) _buildTabBar(),

        if (_tabs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                // Wrap navigation buttons in ListenableBuilder to react to state changes
                ListenableBuilder(
                  listenable: _tabs[_currentTabIndex],
                  builder: (context, _) {
                    final currentTab = _tabs[_currentTabIndex];
                    return Row(
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
                      ],
                    );
                  },
                ),
                // Refresh button doesn't need to be in the ListenableBuilder
                IconButton(
                  icon: const Icon(FluentIcons.refresh),
                  onPressed: () {
                    final controller = _tabs[_currentTabIndex].controller;
                    controller.reload();
                  },
                ),
                // Display current URL if it's from Google, otherwise show "-"
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0),
                    child: ListenableBuilder(
                      listenable: _tabs[_currentTabIndex],
                      builder: (context, _) {
                        final currentUrl = _tabs[_currentTabIndex].currentUrl;
                        final displayText = _isGoogleUrl(currentUrl) ? currentUrl : '-';
                        return Text(
                          displayText,
                          overflow: TextOverflow.ellipsis,
                          style: FluentTheme.of(context).typography.body,
                        );
                      },
                    ),
                  ),
                ),
              ],
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

  Widget _buildTabBar() {
    return Container(
      height: 32,
      margin: const EdgeInsets.only(top: 4.0, left: 4.0, right: 4.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _tabs.length,
        itemBuilder: (context, index) {
          final tab = _tabs[index];
          final isSelected = _currentTabIndex == index;

          // Listen to tab's state changes
          return ListenableBuilder(
            listenable: tab,
            builder: (context, _) {
              return Container(
                margin: const EdgeInsets.only(right: 2.0),
                decoration: BoxDecoration(
                  color: isSelected ? FluentTheme.of(context).accentColor.light : null,
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Tab content area
                    SizedBox(
                      width: 150,
                      child: Button(
                        style: ButtonStyle(
                          backgroundColor: ButtonState.all(Colors.transparent),
                          padding: ButtonState.all(const EdgeInsets.symmetric(horizontal: 8.0)),
                          elevation: ButtonState.all(0), // Remove elevation
                          shadowColor: ButtonState.all(Colors.transparent), // Remove shadow
                          shape: ButtonState.all(RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4.0),
                            side: BorderSide.none, // Remove border
                          )),
                        ),
                        onPressed: () {
                          setState(() {
                            _currentTabIndex = index;
                          });
                        },
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
                                        value: null, // Indeterminate
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
                              color: isSelected
                                  ? Colors.white // 選中時使用白色文字
                                  : null, // 未選中時使用默認顏色
                              fontWeight: isSelected
                                  ? FontWeight.bold // 選中時加粗
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Close button
                Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: IconButton(
                    icon: const Icon(FluentIcons.chrome_close, size: 12),
                    onPressed: () => _closeTab(index),
                    style: ButtonStyle(
                      padding: ButtonState.all(EdgeInsets.zero),
                      iconSize: ButtonState.all(12),
                    ),
                  ),
                ),
              ],
            ),
              );
            },
          );
        }
      )
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
