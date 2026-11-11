import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_plan.dart';
import 'app_controller.dart';

/// The signed-in member's REVO AI plan; null for guests and for repositories
/// without plans. Reloaded whenever a screen watches it again, so usage is
/// current when Profile or the paywall opens.
final aiPlanProvider = FutureProvider.autoDispose<AIPlan?>((ref) async {
  ref.watch(appControllerProvider.select((state) => state.isAuthenticated));
  if (!ref.read(appControllerProvider).isAuthenticated) return null;
  final repository = ref.read(appRepositoryProvider);
  if (repository is! AIPlanSource) return null;
  return (repository as AIPlanSource).loadAIPlan();
}, retry: (_, _) => null);
