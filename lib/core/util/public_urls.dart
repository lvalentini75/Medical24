/// Builds a public URL, accounting for the hash-based preview host.
Uri publicUrl(String path) {
  final Uri base = Uri.base;
  final String normalized = path.startsWith('/') ? path : '/$path';
  if (base.host == 'share.dreamflow.app') {
    return Uri(scheme: base.scheme.isEmpty ? 'https' : base.scheme, host: base.host, port: base.hasPort ? base.port : null, fragment: normalized);
  }
  return Uri(scheme: base.scheme.isEmpty ? 'https' : base.scheme, host: base.host, port: base.hasPort ? base.port : null, path: normalized);
}