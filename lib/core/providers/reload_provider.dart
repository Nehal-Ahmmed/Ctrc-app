import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReloadCommand {
  final int index;
  final int seq;

  const ReloadCommand(this.index, this.seq);
}

class ReloadNotifier extends StateNotifier<ReloadCommand?> {
  ReloadNotifier() : super(null);

  int _seq = 0;

  void triggerReload(int index) {
    state = ReloadCommand(index, ++_seq);
  }
}

final reloadProvider =
    StateNotifierProvider<ReloadNotifier, ReloadCommand?>((ref) {
  return ReloadNotifier();
});
