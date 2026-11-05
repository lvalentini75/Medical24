import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medical24/features/doctor/data/doctor_models.dart';
import 'package:medical24/features/doctor/data/doctor_repository.dart';
import 'package:medical24/features/family/providers/family_providers.dart';

final Provider<DoctorRepository> doctorRepositoryProvider = Provider<DoctorRepository>((Ref ref) => DoctorRepository(ref.watch(currentSubjectProvider).value?.id));
final FutureProvider<List<DoctorShareLink>> doctorLinksProvider = FutureProvider<List<DoctorShareLink>>((Ref ref) => ref.watch(doctorRepositoryProvider).links());
final FutureProvider<DoctorDossier?> doctorDossierProvider = FutureProvider<DoctorDossier?>((Ref ref) => ref.watch(doctorRepositoryProvider).latestDossier());
final FutureProvider<List<DoctorQuestion>> doctorQuestionsProvider = FutureProvider<List<DoctorQuestion>>((Ref ref) => ref.watch(doctorRepositoryProvider).questions());
final FutureProvider<EmergencyCard?> doctorEmergencyCardProvider = FutureProvider<EmergencyCard?>((Ref ref) => ref.watch(doctorRepositoryProvider).emergencyCard());