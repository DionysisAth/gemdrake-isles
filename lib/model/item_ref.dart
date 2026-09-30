import 'package:flutter/foundation.dart';

/// Identifies an item type: a chain and a level within it, e.g. `gem:3`.
@immutable
class ItemRef {
  const ItemRef(this.chain, this.level);

  factory ItemRef.parse(String s) {
    final i = s.indexOf(':');
    if (i <= 0) throw FormatException('Bad item ref "$s"');
    return ItemRef(s.substring(0, i), int.parse(s.substring(i + 1)));
  }

  final String chain;
  final int level;

  ItemRef get next => ItemRef(chain, level + 1);
  String get key => '$chain:$level';

  @override
  bool operator ==(Object other) =>
      other is ItemRef && other.chain == chain && other.level == level;

  @override
  int get hashCode => Object.hash(chain, level);

  @override
  String toString() => key;
}
