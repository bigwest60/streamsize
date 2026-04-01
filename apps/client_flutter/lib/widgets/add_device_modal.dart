import 'package:flutter/material.dart';
import 'package:streamsize_core/streamsize_core.dart';

/// Bottom sheet for manually adding a device to the household list.
/// Returns a [DetectedDevice] on confirm, or null if dismissed.
Future<DetectedDevice?> showAddDeviceModal(BuildContext context) {
  return showModalBottomSheet<DetectedDevice>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => const _AddDeviceSheet(),
  );
}

// Categories shown in the picker — excludes `unknown` (not user-selectable).
const _kPickableCategories = [
  DeviceCategory.tv,
  DeviceCategory.phone,
  DeviceCategory.tablet,
  DeviceCategory.laptop,
  DeviceCategory.console,
  DeviceCategory.camera,
  DeviceCategory.smartHome,
  DeviceCategory.nas,
];

class _AddDeviceSheet extends StatefulWidget {
  const _AddDeviceSheet();

  @override
  State<_AddDeviceSheet> createState() => _AddDeviceSheetState();
}

class _AddDeviceSheetState extends State<_AddDeviceSheet> {
  final _nameController = TextEditingController();
  DeviceCategory _category = DeviceCategory.tv;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _confirm() {
    final name = _nameController.text.trim();
    // Blank name → use category label (prevents empty display name in list).
    final displayName = name.isEmpty ? _category.label : name;
    Navigator.of(context).pop(
      DetectedDevice(
        displayName: displayName,
        category: _category,
        confidence: ConfidenceScore.high,
        connection: ConnectionType.wifi,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add a device', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Add a device that the scan may have missed.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Device name (optional)',
              hintText: 'e.g. Office NAS, Kids iPad',
            ),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<DeviceCategory>(
            initialValue: _category,
            decoration: const InputDecoration(labelText: 'Device type'),
            items: _kPickableCategories
                .map(
                  (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _category = value);
            },
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _confirm,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18)),
                  ),
                  child: const Text('Add device'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
