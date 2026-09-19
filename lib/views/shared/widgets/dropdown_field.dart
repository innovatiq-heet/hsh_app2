import 'package:flutter/material.dart';

class DropdownField<T> extends StatelessWidget {
  final String label;
  final T? value;
  final List<T> items;
  final String Function(T) itemLabel;
  final void Function(T?) onChanged;
  final bool enabled;

  const DropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.items,
    required this.itemLabel,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: items
          .map(
            (e) => DropdownMenuItem<T>(
              value: e,
              child: Text(itemLabel(e), overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: enabled ? onChanged : null,
    );
  }
}
