import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:intl/intl.dart';

class LogAccordion<T> extends StatefulWidget {
  final List<T> items;
  final DateTime Function(T) getTimestamp;
  final Widget Function(BuildContext, T) itemBuilder;
  final String? emptyMessage;

  const LogAccordion({
    super.key,
    required this.items,
    required this.getTimestamp,
    required this.itemBuilder,
    this.emptyMessage,
  });

  @override
  State<LogAccordion<T>> createState() => _LogAccordionState<T>();
}

class _LogAccordionState<T> extends State<LogAccordion<T>> {
  final Set<int> _expandedIndices = {0};

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text(widget.emptyMessage ?? 'No logs found.')),
      );
    }

    final groupedItems = <String, List<T>>{};
    final monthKeys = <String>[];

    for (final item in widget.items) {
      final timestamp = widget.getTimestamp(item);
      final key = DateFormat('MMMM yyyy').format(timestamp);
      if (!groupedItems.containsKey(key)) {
        groupedItems[key] = [];
        monthKeys.add(key);
      }
      groupedItems[key]!.add(item);
    }

    return FAccordion(
      control: FAccordionControl.lifted(
        expanded: (index) => _expandedIndices.contains(index),
        onChange: (index, expanded) => setState(() {
          if (expanded) {
            _expandedIndices.add(index);
          } else {
            _expandedIndices.remove(index);
          }
        }),
      ),
      children: monthKeys.asMap().entries.map((entry) {
        final monthKey = entry.value;
        final itemsInMonth = groupedItems[monthKey]!;

        return FAccordionItem(
          title: Text(monthKey),
          child: Column(
            children: itemsInMonth.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: widget.itemBuilder(context, item),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}
