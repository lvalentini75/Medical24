import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:medical24/supabase/supabase_config.dart';

class FamilySubject {
  const FamilySubject({required this.id, required this.fullName, required this.role, required this.managed, this.relationship});
  final String id;
  final String fullName;
  final String role;
  final bool managed;
  final String? relationship;

  factory FamilySubject.fromJson(Map<String, dynamic> json) => FamilySubject(id: json['subject_id'].toString(), fullName: (json['full_name'] ?? '').toString(), role: (json['role'] ?? 'caregiver').toString(), managed: json['managed'] == true, relationship: json['relationship']?.toString());
}

class FamilyInvitation {
  const FamilyInvitation({required this.id, required this.subjectId, required this.subjectName, this.relationship, this.createdAt, this.invitedBy});
  final String id;
  final String subjectId;
  final String subjectName;
  final String? relationship;
  final DateTime? createdAt;
  final String? invitedBy;

  factory FamilyInvitation.fromJson(Map<String, dynamic> json) => FamilyInvitation(id: json['id'].toString(), subjectId: json['subject_id'].toString(), subjectName: (json['subject_name'] ?? '').toString(), relationship: json['relationship']?.toString(), createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''), invitedBy: json['invited_by']?.toString());
}

class FamilyDelegate {
  const FamilyDelegate({required this.id, required this.subjectId, required this.status, required this.role, this.email, this.userId, this.relationship});
  final String id;
  final String subjectId;
  final String status;
  final String role;
  final String? email;
  final String? userId;
  final String? relationship;

  factory FamilyDelegate.fromJson(Map<String, dynamic> json) => FamilyDelegate(id: json['id'].toString(), subjectId: json['subject_id'].toString(), status: json['status'].toString(), role: json['role'].toString(), email: json['invited_email']?.toString(), userId: json['user_id']?.toString(), relationship: json['relationship']?.toString());
}

class ManagedMemberInput {
  const ManagedMemberInput({required this.fullName, this.birthDate, this.gender, this.relationship});
  final String fullName;
  final DateTime? birthDate;
  final String? gender;
  final String? relationship;

  Map<String, dynamic> toJson({bool declarationAccepted = false}) => <String, dynamic>{'full_name': fullName, if (birthDate != null) 'birth_date': _date(birthDate!), if (gender != null) 'gender': gender, if (relationship != null) 'relationship': relationship, if (declarationAccepted) 'declaration_accepted': true};
  static String _date(DateTime value) => '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

class CaregiverInviteInput {
  const CaregiverInviteInput({required this.email, this.relationship});
  final String email;
  final String? relationship;
}

class FamilyFailure implements Exception {
  const FamilyFailure(this.code, {this.status});
  final String code;
  final int? status;
}

abstract interface class FamilyRepository {
  Future<List<FamilySubject>> mySubjects();
  Future<List<FamilyInvitation>> pendingInvitations();
  Future<List<FamilyDelegate>> delegates();
  Future<int> managedLimit();
  Future<FamilySubject> createMember(ManagedMemberInput input);
  Future<void> updateMember(String subjectId, ManagedMemberInput input);
  Future<void> removeMember(String subjectId);
  Future<void> invite(String subjectId, CaregiverInviteInput input);
  Future<void> accept(String invitationId);
  Future<void> revoke(String delegateId);
  Future<void> logSubjectView(String subjectId);
}

class SupabaseFamilyRepository implements FamilyRepository {
  const SupabaseFamilyRepository();
  SupabaseClient get _client => SupabaseConfig.client;

  @override
  Future<List<FamilySubject>> mySubjects() async => _rows(await _rpc('my_subjects')).map(FamilySubject.fromJson).toList();
  @override
  Future<List<FamilyInvitation>> pendingInvitations() async => _rows(await _rpc('my_pending_invitations')).map(FamilyInvitation.fromJson).toList();
  @override
  Future<List<FamilyDelegate>> delegates() async {
    try {
      final List<dynamic> rows = await _client.from('subject_delegates').select('id,subject_id,user_id,invited_email,role,status,relationship,created_at').order('created_at', ascending: false);
      return rows.map((dynamic row) => FamilyDelegate.fromJson(Map<String, dynamic>.from(row as Map))).toList();
    } on PostgrestException catch (error) { throw _failure(error); }
  }
  @override
  Future<int> managedLimit() async { final dynamic value = await _rpc('family_managed_limit'); return value is num ? value.toInt() : int.tryParse(value.toString()) ?? 0; }
  @override
  Future<FamilySubject> createMember(ManagedMemberInput input) async {
    try {
      final FunctionResponse response = await _client.functions.invoke('family-member-create', body: input.toJson(declarationAccepted: true));
      final Map<String, dynamic> json = Map<String, dynamic>.from(response.data as Map);
      return FamilySubject(id: json['subject_id'].toString(), fullName: json['full_name'].toString(), role: 'owner', managed: true, relationship: input.relationship);
    } on FunctionException catch (error) {
      final dynamic details = error.details;
      throw FamilyFailure(details is Map ? (details['code'] ?? 'server_error').toString() : 'server_error', status: error.status);
    } on TypeError { throw const FamilyFailure('invalid_response', status: 500); }
  }
  @override
  Future<void> updateMember(String subjectId, ManagedMemberInput input) async => _voidRpc('family_member_update', <String, dynamic>{'p_subject': subjectId, 'p_full_name': input.fullName, if (input.birthDate != null) 'p_birth_date': ManagedMemberInput._date(input.birthDate!), if (input.gender != null) 'p_gender': input.gender, if (input.relationship != null) 'p_relationship': input.relationship});
  @override
  Future<void> removeMember(String subjectId) async {
    try {
      await _client.functions.invoke('family-member-remove', body: <String, dynamic>{'subject_id': subjectId});
    } on FunctionException catch (error) {
      final dynamic details = error.details;
      throw FamilyFailure(details is Map ? (details['code'] ?? 'server_error').toString() : 'server_error', status: error.status);
    }
  }
  @override
  Future<void> invite(String subjectId, CaregiverInviteInput input) async => _voidRpc('delegate_invite', <String, dynamic>{'p_subject': subjectId, 'p_email': input.email, if (input.relationship != null) 'p_relationship': input.relationship});
  @override
  Future<void> accept(String invitationId) async => _voidRpc('delegate_accept', <String, dynamic>{'p_id': invitationId});
  @override
  Future<void> revoke(String delegateId) async => _voidRpc('delegate_revoke', <String, dynamic>{'p_id': delegateId});
  @override
  Future<void> logSubjectView(String subjectId) async => _voidRpc('subject_view_log', <String, dynamic>{'p_subject': subjectId});

  Future<dynamic> _rpc(String name, [Map<String, dynamic>? params]) async { try { return await _client.rpc(name, params: params); } on PostgrestException catch (error) { throw _failure(error); } }
  Future<void> _voidRpc(String name, Map<String, dynamic> params) async { await _rpc(name, params); }
  List<Map<String, dynamic>> _rows(dynamic value) => (value as List<dynamic>).map((dynamic row) => Map<String, dynamic>.from(row as Map)).toList();
  FamilyFailure _failure(PostgrestException error) {
    const List<String> codes = <String>['managed_limit', 'too_many_delegates', 'already_invited', 'not_invited', 'invalid_email', 'invalid_subject', 'not_allowed'];
    return FamilyFailure(codes.firstWhere((String code) => error.message.contains(code), orElse: () => 'server_error'));
  }
}