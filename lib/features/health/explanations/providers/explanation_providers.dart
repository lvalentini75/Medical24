import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical24/features/health/explanations/data/explanation_repository.dart';

final Provider<ExplanationRepository> explanationRepositoryProvider = Provider<ExplanationRepository>((Ref ref) => const SupabaseExplanationRepository());

/// Revision observed by explanation cards after clinical values change.
class ExplanationRefreshNotifier extends Notifier<int> {
  @override
  int build() => 0;
  void refresh() => state++;
}

final NotifierProvider<ExplanationRefreshNotifier, int> explanationRefreshProvider = NotifierProvider<ExplanationRefreshNotifier, int>(ExplanationRefreshNotifier.new);