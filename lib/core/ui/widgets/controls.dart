import 'package:flutter/material.dart';
import 'package:medical24/core/ui/icons.dart';
import 'package:medical24/core/ui/tokens.dart';

class M24Segment<T> {
  const M24Segment({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

class M24Segmented<T> extends StatelessWidget {
  const M24Segmented({super.key, required this.segments, required this.selected, required this.onChanged});
  final List<M24Segment<T>> segments;
  final T selected;
  final ValueChanged<T>? onChanged;
  @override
  Widget build(BuildContext context) => SegmentedButton<T>(segments: segments.map((s) => ButtonSegment<T>(value: s.value, label: Text(s.label), icon: s.icon == null ? null : Icon(s.icon, size: 20))).toList(), selected: <T>{selected}, showSelectedIcon: false, onSelectionChanged: onChanged == null ? null : (Set<T> values) => onChanged!(values.first));
}

class M24FilterChip extends StatelessWidget {
  const M24FilterChip({super.key, required this.label, required this.selected, this.onSelected, this.icon, this.hasMenu = false});
  final String label;
  final bool selected, hasMenu;
  final ValueChanged<bool>? onSelected;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => FilterChip(selected: selected, onSelected: onSelected, avatar: icon == null ? null : Icon(icon, size: 18), label: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[Text(label), if (hasMenu) ...<Widget>[const SizedBox(width: 6), const Icon(M24Icons.chevronDown, size: 18)]]), materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, visualDensity: const VisualDensity(vertical: 2));
}

class M24SearchField extends StatelessWidget {
  const M24SearchField({super.key, this.controller, required this.hintText, this.onChanged, this.enabled = true});
  final TextEditingController? controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) => SizedBox(height: 48, child: TextField(controller: controller, enabled: enabled, onChanged: onChanged, style: context.m24.text.body, decoration: InputDecoration(hintText: hintText, prefixIcon: Icon(M24Icons.search, size: 20, color: context.m24.colors.inkMuted))));
}

class M24Tabs extends StatelessWidget {
  const M24Tabs({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => DefaultTabController(length: labels.length, initialIndex: index, child: TabBar(isScrollable: true, tabAlignment: TabAlignment.start, onTap: onChanged, tabs: labels.map((label) => Tab(text: label)).toList()));
}