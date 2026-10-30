import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical24/features/home/data/home_models.dart';
import 'package:medical24/features/home/data/home_repository.dart';

final Provider<HomeRepository> homeRepositoryProvider = Provider<HomeRepository>((Ref ref) => const SupabaseHomeRepository());
final FutureProvider<HomeSnapshot> homeSnapshotProvider = FutureProvider<HomeSnapshot>((Ref ref) => ref.watch(homeRepositoryProvider).snapshot());