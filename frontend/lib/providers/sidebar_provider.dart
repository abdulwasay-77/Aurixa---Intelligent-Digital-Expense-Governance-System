/// Sidebar State Management (Collapse/Expand)
/// Always starts expanded.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

class SidebarNotifier extends StateNotifier<bool> {
  SidebarNotifier() : super(false); // false = expanded, true = collapsed

  void toggle() {
    state = !state;
  }

  void expand() {
    state = false;
  }

  void collapse() {
    state = true;
  }
}

final sidebarProvider =
    StateNotifierProvider<SidebarNotifier, bool>((ref) {
  return SidebarNotifier();
});