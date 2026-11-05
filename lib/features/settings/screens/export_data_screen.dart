import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';
import 'package:medical24/core/ui/widgets/buttons.dart';
import 'package:medical24/core/ui/widgets/feedback.dart';
import 'package:medical24/core/ui/widgets/surfaces.dart';
import 'package:medical24/features/settings/data/settings_privacy_repository.dart';
import 'package:medical24/features/settings/data/settings_privacy_localizations.dart';
import 'package:medical24/l10n/generated/localization_lookup.dart';

/// Privacy screen that requests and downloads the user's portable data package.
class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key, required this.onBack, this.repository = const SupabaseSettingsPrivacyRepository(), this.initialExport, this.loadOnStart = true});

  final VoidCallback onBack;
  final SettingsPrivacyRepository repository;
  final DataExportState? initialExport;
  final bool loadOnStart;

  @override
  State<ExportDataScreen> createState() => _ExportDataScreenState();
}

class _ExportDataScreenState extends State<ExportDataScreen> {
  DataExportState? _export;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _export = widget.initialExport;
    if (widget.loadOnStart) WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    setState(() { _loading = true; _error = null; });
    try {
      final DataExportState? value = await widget.repository.latestExport();
      if (mounted) setState(() => _export = value);
    } on SettingsPrivacyException catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.settingsExportErrorServer);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _request() async {
    setState(() { _loading = true; _error = null; });
    try {
      final DataExportState value = await widget.repository.requestExport();
      if (mounted) setState(() => _export = value);
    } on SettingsPrivacyException catch (error) {
      if (mounted) setState(() => _error = _messageFor(error));
    } catch (_) {
      if (mounted) setState(() => _error = context.l10n.settingsExportErrorServer);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _messageFor(SettingsPrivacyException error) {
    if (error.status == 429 || error.code == 'daily_limit') {
      final DateTime? requestedAt = _export?.requestedAt;
      if (requestedAt == null) return context.l10n.settingsExportErrorDailyGeneric;
      final Duration left = requestedAt.add(const Duration(hours: 24)).difference(DateTime.now().toUtc());
      final int hours = left.inMinutes <= 0 ? 1 : (left.inMinutes / 60).ceil();
      return context.l10n.settingsExportErrorDaily(hours);
    }
    if (error.status == 403 || error.code == 'not_allowed') return context.l10n.settingsExportErrorForbidden;
    return context.l10n.settingsExportErrorServer;
  }

  Future<void> _download() async {
    final Uri? uri = Uri.tryParse(_export?.url ?? '');
    if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) setState(() => _error = context.l10n.settingsExportDownloadError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(leading: IconButton(icon: const Icon(M24Icons.chevronLeft), tooltip: l10n.commonBack, onPressed: widget.onBack), title: Text(l10n.settingsExportTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              Text(l10n.settingsExportExplanation, style: Theme.of(context).textTheme.bodyLarge),
              const SizedBox(height: 24),
              M24Card(child: ExportStatusContent(export: _export, loading: _loading, error: _error)),
              const SizedBox(height: 16),
              if (_export?.truncated == true) M24Banner(title: l10n.settingsExportIncompleteTitle, subtitle: l10n.settingsExportIncompleteBody),
              if (_export?.truncated == true) const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: <Widget>[
                M24Button(key: const Key('export-request'), label: l10n.settingsExportRequest, icon: M24Icons.download, loading: _loading, onPressed: _loading ? null : _request),
                M24Button(key: const Key('export-refresh'), label: l10n.settingsExportRefresh, icon: M24Icons.refresh, variant: M24ButtonVariant.outline, onPressed: _loading ? null : _refresh),
                if (_export?.status == 'ready' && _export?.url != null) M24Button(key: const Key('export-download'), label: l10n.settingsExportDownload, icon: M24Icons.download, variant: M24ButtonVariant.outlinePrimary, onPressed: _download),
              ]),
              if (_loading) ...<Widget>[const SizedBox(height: 16), Text(l10n.settingsExportWait, style: context.m24.text.bodySmall)],
            ],
          ),
        ),
      ),
    );
  }
}

/// Localized content for every state returned by `data_export_latest`.
class ExportStatusContent extends StatelessWidget {
  const ExportStatusContent({super.key, required this.export, required this.loading, required this.error});

  final DataExportState? export;
  final bool loading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (loading && export == null) return const Center(child: CircularProgressIndicator());
    if (error != null) return _Status(icon: M24Icons.error, title: l10n.commonErrorTitle, body: error!);
    if (export == null) return _Status(icon: M24Icons.info, title: l10n.settingsExportNoneTitle, body: l10n.settingsExportNoneBody);
    final DataExportState value = export!;
    return switch (value.status) {
      'pending' => _Status(icon: M24Icons.clock, title: l10n.settingsExportPendingTitle, body: l10n.settingsExportPendingBody),
      'ready' => _Status(icon: M24Icons.confirm, title: l10n.settingsExportReadyTitle, body: l10n.settingsExportReadyDetails(_date(context, value.expiresAt), _bytes(value.bytes), value.fileCount ?? 0)),
      'failed' => _Status(icon: M24Icons.error, title: l10n.settingsExportFailedTitle, body: _failedMessage(l10n, value.errorCode)),
      'expired' => _Status(icon: M24Icons.clock, title: l10n.settingsExportExpiredTitle, body: l10n.settingsExportExpiredBody),
      _ => _Status(icon: M24Icons.info, title: l10n.settingsExportNoneTitle, body: l10n.settingsExportNoneBody),
    };
  }

  static String _date(BuildContext context, DateTime? value) => value == null ? context.l10n.settingsExportDateUnavailable : DateFormat.yMMMd(Localizations.localeOf(context).languageCode).add_Hm().format(value.toLocal());
  static String _bytes(int? value) {
    if (value == null) return '-';
    if (value >= 1024 * 1024) return '${(value / (1024 * 1024)).toStringAsFixed(1)} MB';
    if (value >= 1024) return '${(value / 1024).toStringAsFixed(1)} KB';
    return '$value B';
  }
  static String _failedMessage(AppLocalizations l10n, String? code) => switch (code) {
    'build_failed' => l10n.settingsExportFailureBuild,
    'upload_failed' => l10n.settingsExportFailureUpload,
    'finish_failed' || 'sign_failed' => l10n.settingsExportFailureFinalize,
    _ => l10n.settingsExportFailureUnknown,
  };
}

class _Status extends StatelessWidget {
  const _Status({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
    M24IconTile(icon: icon, variant: M24IconTileVariant.primary),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[Text(title, style: context.m24.text.title), const SizedBox(height: 4), Text(body, style: context.m24.text.bodySmall)])),
  ]);
}