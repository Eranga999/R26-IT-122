// lib/widgets/location_selector.dart
import 'package:flutter/material.dart';
import '../data/sigiriya_knowledge_base.dart';

class LocationSelector extends StatefulWidget {
  final TextEditingController controller;
  final String? selectedLocation;
  final ValueChanged<String?> onSelected;

  const LocationSelector({
    super.key,
    required this.controller,
    required this.selectedLocation,
    required this.onSelected,
  });

  @override
  State<LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends State<LocationSelector> {
  bool _showDropdown = false;
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    final q = widget.controller.text.toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _suggestions = [];
        _showDropdown = false;
      });
      widget.onSelected(null);
      return;
    }
    final filtered = kLocationNames
        .where((n) => n.toLowerCase().contains(q))
        .toList();
    setState(() {
      _suggestions = filtered;
      _showDropdown = filtered.isNotEmpty;
    });
  }

  void _selectLocation(String name) {
    widget.controller.text = name;
    widget.onSelected(name);
    setState(() => _showDropdown = false);
  }

  @override
  Widget build(BuildContext context) {
    final gold = Theme.of(context).colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Input row ──────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: widget.controller,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Type or pick a location…',
                  prefixIcon: Icon(Icons.location_on_outlined, color: gold),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.controller.text.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          color: Colors.white38,
                          onPressed: () {
                            widget.controller.clear();
                            widget.onSelected(null);
                          },
                        ),
                      IconButton(
                        icon: Icon(
                          _showDropdown
                              ? Icons.arrow_drop_up
                              : Icons.arrow_drop_down,
                          color: gold,
                        ),
                        onPressed: () => setState(() {
                          if (_showDropdown) {
                            _showDropdown = false;
                          } else {
                            _suggestions = kLocationNames;
                            _showDropdown = true;
                          }
                        }),
                      ),
                    ],
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                ),
              ),
            ),
          ],
        ),

        // ── Dropdown list ──────────────────────────────────────────
        if (_showDropdown)
          Container(
            margin: const EdgeInsets.only(top: 4),
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: const Color(0xFF2C1A0E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: gold.withOpacity(0.4)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) =>
                  Divider(color: gold.withOpacity(0.1), height: 1),
              itemBuilder: (context, index) {
                final name = _suggestions[index];
                final loc = kSigiriyaLocations.firstWhere(
                  (l) => l.name == name,
                );
                final isSelected = widget.selectedLocation == name;

                return InkWell(
                  onTap: () => _selectLocation(name),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Text(loc.emoji,
                            style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              color: isSelected ? gold : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (isSelected)
                          Icon(Icons.check, color: gold, size: 16),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
