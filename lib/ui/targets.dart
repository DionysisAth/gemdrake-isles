import 'package:flutter/widgets.dart';

/// Lets the tutorial pointer and fly-to-counter effects find where things
/// are on screen (global coordinates), e.g. `generator:crystal_mine`,
/// `order:0`, `tab:island`, `hud:coins`.
class TargetRegistry {
  final _resolvers = <String, List<Rect> Function(String arg)>{};
  final _keys = <String, GlobalKey>{};

  void register(String prefix, List<Rect> Function(String arg) resolver) =>
      _resolvers[prefix] = resolver;

  void unregister(String prefix) => _resolvers.remove(prefix);

  /// Returns a stable key for [id] to attach to a widget.
  GlobalKey keyFor(String id) =>
      _keys.putIfAbsent(id, () => GlobalKey(debugLabel: id));

  List<Rect> rects(String target) {
    final key = _keys[target];
    if (key != null) {
      final r = rectOfKey(key);
      if (r != null) return [r];
    }
    final i = target.indexOf(':');
    if (i > 0) {
      final resolver = _resolvers[target.substring(0, i)];
      if (resolver != null) return resolver(target.substring(i + 1));
    }
    return const [];
  }

  Rect? rect(String target) {
    final r = rects(target);
    return r.isEmpty ? null : r.first;
  }

  static Rect? rectOfKey(GlobalKey key) {
    final ctx = key.currentContext;
    final box = ctx?.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
