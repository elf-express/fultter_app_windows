

import 'package:fluent_ui/fluent_ui.dart';

import '../../models/webview_item.dart';

/// ------------------------------------------------------------
/// HomeArea：Home 具有分頁列 + 工具列(含網址列)
/// ------------------------------------------------------------
class HomeArea extends StatefulWidget {
  final List<WebViewItem> tabs;
  final int currentIndex;

  final void Function(int index) onSelect;
  final VoidCallback onAdd;
  final void Function(int index) onClose;

  final Widget Function(WebViewItem item) buildWebView;
  final Future<void> Function(WebViewItem item, String raw) onUrlSubmitted;

  const HomeArea({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onSelect,
    required this.onAdd,
    required this.onClose,
    required this.buildWebView,
    required this.onUrlSubmitted,
  });

  @override
  State<HomeArea> createState() => _HomeAreaState();
}

class _HomeAreaState extends State<HomeArea> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  int _hoverTabIndex = -1;   // 目前 hover 的分頁 index
  bool _hoverAdd = false;    // 右側「+」是否 hover

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.tabs.isEmpty) return const Center(child: Text('尚無分頁'));

    final current = widget.tabs[widget.currentIndex];

    return Column(
      children: [
        _buildTabBar(),
        _buildToolbar(current),
        Expanded(
          child: IndexedStack(
            index: widget.currentIndex.clamp(0, widget.tabs.length - 1),
            children: widget.tabs.map(widget.buildWebView).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey[20],
        border: Border(bottom: BorderSide(color: Colors.grey[60], width: 1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: widget.tabs.length,
              itemBuilder: (context, index) {
                final item = widget.tabs[index];
                final selected = index == widget.currentIndex;
                final hovered = index == _hoverTabIndex;

                final bg = selected
                    ? Colors.white
                    : (hovered ? Colors.grey[30] : Colors.grey[20]);

                final textColor = selected
                    ? Colors.black
                    : (hovered ? Colors.black : Colors.black.withValues(alpha: 0.7));

                return MouseRegion(
                  onEnter: (_) => setState(() => _hoverTabIndex = index),
                  onExit:  (_) => setState(() => _hoverTabIndex = -1),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    margin: const EdgeInsets.only(right: 4, top: 4, bottom: 0),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        topRight: Radius.circular(8),
                      ),
                      // ⚠️ 這裡一定要「統一顏色」的邊框，否則會觸發你貼的錯誤
                      border: (selected || hovered)
                          ? Border.all(color: Colors.grey[100], width: 1)
                          : null,
                      boxShadow: (selected || hovered)
                          ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: selected ? 0.18 : 0.08),
                          blurRadius: selected ? 3 : 2,
                          offset: const Offset(0, 1),
                        ),
                      ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onSelect(index),
                          child: AnimatedBuilder(
                            animation: item,
                            builder: (_, __) {
                              final label = item.title.trim().isNotEmpty
                                  ? item.title.trim()
                                  : (() {
                                try {
                                  final uri = Uri.parse(item.currentUrl);
                                  return uri.host.isNotEmpty ? uri.host : item.currentUrl;
                                } catch (_) {
                                  return item.currentUrl;
                                }
                              })();
                              final text = label.length <= 22 ? label : '${label.substring(0, 21)}…';
                              return Text(
                                text,
                                style: TextStyle(
                                  color: textColor,
                                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 6),
                        if (widget.tabs.length > 1)
                          (hovered || selected)
                              ? _CloseButtonChromeLike(onTap: () => widget.onClose(index))
                              : const SizedBox(width: 18, height: 18),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          MouseRegion(
            onEnter: (_) => setState(() => _hoverAdd = true),
            onExit:  (_) => setState(() => _hoverAdd = false),
            child: GestureDetector(
              onTap: widget.onAdd,
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin: const EdgeInsets.only(right: 6),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: _hoverAdd ? Colors.grey[40] : Colors.transparent,
                  shape: BoxShape.circle,
                ),
                child: const Icon(FluentIcons.add, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(WebViewItem current) {
    return AnimatedBuilder(
      animation: current,
      builder: (context, _) {
        final urlController = TextEditingController(text: current.currentUrl);
        return Container(
          height: 44,
          decoration: BoxDecoration(
            color: Colors.grey[10],
            border: Border(bottom: BorderSide(color: Colors.grey[60], width: 1)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              IconButton(icon: const Icon(FluentIcons.back), onPressed: current.canGoBack ? () => current.back() : null),
              IconButton(icon: const Icon(FluentIcons.forward), onPressed: current.canGoForward ? () => current.forward() : null),
              IconButton(icon: const Icon(FluentIcons.refresh), onPressed: () => current.controller?.reload()),
              const SizedBox(width: 8),
              Expanded(
                child: TextBox(
                  controller: urlController,
                  placeholder: '輸入網址或搜尋關鍵字',
                  onSubmitted: (value) => widget.onUrlSubmitted(current, value),
                  onTap: () {
                    urlController.selection = TextSelection(baseOffset: 0, extentOffset: urlController.text.length);
                  },
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 8.0, right: 8.0),
                    child: Icon(FluentIcons.search, size: 16),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CloseButtonChromeLike extends StatefulWidget {
  final VoidCallback onTap;
  const _CloseButtonChromeLike({required this.onTap});

  @override
  State<_CloseButtonChromeLike> createState() => _CloseButtonChromeLikeState();
}

class _CloseButtonChromeLikeState extends State<_CloseButtonChromeLike> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: _hover ? Colors.grey[60] : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: Icon(
            FluentIcons.chrome_close,
            size: 12,
            color: _hover ? Colors.white : Colors.grey[140],
          ),
        ),
      ),
    );
  }
}