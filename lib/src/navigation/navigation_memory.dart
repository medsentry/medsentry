import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers where each person was in the app, so a refresh or restart
/// opens the same place: the last screen they used (per account) and the
/// open tab of every tabbed screen (per device).
///
/// Values are kept in memory and written through to shared_preferences.
/// [load] runs once at startup, before the first screen is built, so tab
/// controllers can read their starting tab synchronously.
class NavigationMemory {
  NavigationMemory._(this._prefs, this._values);

  final SharedPreferences? _prefs;
  final Map<String, String> _values;

  static NavigationMemory _instance = NavigationMemory._(null, {});

  /// The loaded memory. Until [load] finishes it is an empty, in-memory
  /// store, so callers never have to wait or handle null.
  static NavigationMemory get instance => _instance;

  static const _prefix = 'nav.';

  /// Reads the stored values. Never throws: without storage the app still
  /// works and simply does not remember across restarts.
  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final values = <String, String>{
        for (final key in prefs.getKeys())
          if (key.startsWith(_prefix) && prefs.get(key) is String)
            key: prefs.getString(key)!,
      };
      _instance = NavigationMemory._(prefs, values);
    } catch (error) {
      debugPrint('Navigation memory unavailable: $error');
    }
  }

  /// Replaces the memory in tests.
  @visibleForTesting
  static void debugReset([Map<String, String> values = const {}]) {
    _instance = NavigationMemory._(null, Map.of(values));
  }

  String? _read(String key) => _values[_prefix + key];

  void _write(String key, String value) {
    if (_values[_prefix + key] == value) return;
    _values[_prefix + key] = value;
    _prefs?.setString(_prefix + key, value).catchError((Object error) {
      debugPrint('Could not save navigation memory: $error');
      return false;
    });
  }

  /// The last screen [userId] had open, as a location such as
  /// `/certificates?tab=registry`.
  String? lastLocation(String userId) => _read('last.$userId');

  /// Records [location] as the screen [userId] has open. The sign-in page
  /// is not a place to return to and is ignored.
  void rememberLocation(String userId, Uri location) {
    final path = location.path;
    if (path.isEmpty || path == '/' || path.startsWith('/login')) return;
    _write('last.$userId', location.toString());
  }

  /// The slug of the tab last open on [screen].
  String? tab(String screen) => _read('tab.$screen');

  void rememberTab(String screen, String slug) => _write('tab.$screen', slug);
}

/// The tabs of one screen, named by short slugs that appear in the address
/// (`/certificates?tab=registry`) and in storage, so a link, a refresh or a
/// restart reopens the same tab.
class TabMemory {
  const TabMemory(this.screen, this.tabs);

  /// Storage name of the screen, e.g. `certificates`.
  final String screen;

  /// One slug per tab, in tab order, e.g. `['issue', 'registry']`.
  final List<String> tabs;

  static const queryKey = 'tab';

  /// The tab to open first: the address's `?tab=` (a shared link or a
  /// refresh), else the last tab used on this device, else the first tab.
  int initialIndex(BuildContext context) {
    final fromUrl = _currentUri(context)?.queryParameters[queryKey];
    final fromUrlIndex = fromUrl == null ? -1 : tabs.indexOf(fromUrl);
    if (fromUrlIndex >= 0) return fromUrlIndex;
    final stored = NavigationMemory.instance.tab(screen);
    final storedIndex = stored == null ? -1 : tabs.indexOf(stored);
    return storedIndex >= 0 ? storedIndex : 0;
  }

  /// A [TabController] that starts on [initialIndex] and records every tab
  /// change. The caller disposes it as usual.
  TabController createController({
    required BuildContext context,
    required TickerProvider vsync,
  }) {
    final controller = TabController(
      length: tabs.length,
      vsync: vsync,
      initialIndex: initialIndex(context),
    );
    controller.addListener(() {
      // Fires at the start and end of an animated change; record once the
      // new tab has settled.
      if (controller.indexIsChanging || !context.mounted) return;
      remember(context, controller.index);
    });
    return controller;
  }

  /// Saves tab [index] and writes it into the address in place, without a
  /// new history entry or reloading the page. The page keeps its state
  /// because only the query changes, not the route.
  void remember(BuildContext context, int index) {
    if (index < 0 || index >= tabs.length) return;
    final slug = tabs[index];
    NavigationMemory.instance.rememberTab(screen, slug);

    final router = GoRouter.maybeOf(context);
    final uri = _currentUri(context);
    if (router == null || uri == null) return;
    if (uri.queryParameters[queryKey] == slug) return;
    final updated = uri.replace(
      queryParameters: {...uri.queryParameters, queryKey: slug},
    );
    router.replace(updated.toString());
  }

  static Uri? _currentUri(BuildContext context) {
    final router = GoRouter.maybeOf(context);
    if (router == null) return null;
    return router.routerDelegate.currentConfiguration.uri;
  }
}

/// Owns a remembered [TabController] for screens that are stateless, such
/// as the patient record: [builder] receives the controller to pass to the
/// screen's TabBar and TabBarView.
class RememberedTabs extends StatefulWidget {
  const RememberedTabs({
    super.key,
    required this.memory,
    required this.builder,
  });

  final TabMemory memory;
  final Widget Function(BuildContext context, TabController controller)
  builder;

  @override
  State<RememberedTabs> createState() => _RememberedTabsState();
}

class _RememberedTabsState extends State<RememberedTabs>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = widget.memory.createController(
    context: context,
    vsync: this,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _controller);
}

/// Keeps a tab's subtree alive while another tab is shown, so its scroll
/// position, text fields and expanded sections are as the person left them.
/// TabBarView otherwise disposes every tab that is off screen.
class KeepAliveTab extends StatefulWidget {
  const KeepAliveTab({super.key, required this.child});

  final Widget child;

  @override
  State<KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
