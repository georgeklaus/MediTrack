import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/provider_service.dart';
import '../../theme/app_theme.dart';

class ProviderAvailabilityScreen extends StatefulWidget {
  const ProviderAvailabilityScreen({super.key});

  @override
  State<ProviderAvailabilityScreen> createState() =>
      _ProviderAvailabilityScreenState();
}

class _ProviderAvailabilityScreenState
    extends State<ProviderAvailabilityScreen> {
  final _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  final Map<String, bool> _selectedDays = {};
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final d in _days) {
      _selectedDays[d] = false;
    }
    _loadAvailability();
  }

  Future<void> _loadAvailability() async {
    final data =
        await context.read<ProviderService>().getAvailability();
    if (data != null && mounted) {
      final workingDays =
          List<String>.from(data['workingDays'] as List? ?? []);
      final startStr = data['startTime'] as String? ?? '08:00';
      final endStr = data['endTime'] as String? ?? '17:00';
      final startParts = startStr.split(':');
      final endParts = endStr.split(':');
      setState(() {
        for (final d in _days) {
          _selectedDays[d] = workingDays.contains(d);
        }
        _startTime = TimeOfDay(
            hour: int.parse(startParts[0]),
            minute: int.parse(startParts[1]));
        _endTime = TimeOfDay(
            hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));
      });
    }
    setState(() => _loading = false);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final selected =
        _days.where((d) => _selectedDays[d] == true).toList();
    await context.read<ProviderService>().saveAvailability({
      'workingDays': selected,
      'startTime':
          '${_startTime.hour.toString().padLeft(2, '0')}:${_startTime.minute.toString().padLeft(2, '0')}',
      'endTime':
          '${_endTime.hour.toString().padLeft(2, '0')}:${_endTime.minute.toString().padLeft(2, '0')}',
    });
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Availability saved.')));
    }
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Availability',
                        style: Theme.of(context).textTheme.headlineLarge),
                    const SizedBox(height: 20),
                    Text('Working Days',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _days.map((day) {
                        final selected = _selectedDays[day] == true;
                        return FilterChip(
                          label: Text(day.substring(0, 3)),
                          selected: selected,
                          onSelected: (val) =>
                              setState(() => _selectedDays[day] = val),
                          selectedColor: AppColors.primary,
                          checkmarkColor: Colors.white,
                          labelStyle: TextStyle(
                            color: selected ? Colors.white : AppColors.textPrimary,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    Text('Working Hours',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _TimeTile(
                            label: 'Start Time',
                            time: _startTime.format(context),
                            onTap: () => _pickTime(true),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TimeTile(
                            label: 'End Time',
                            time: _endTime.format(context),
                            onTap: () => _pickTime(false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    _saving
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _save,
                            child: const Text('Save Availability'),
                          ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimeTile({
    required this.label,
    required this.time,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Text(time,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
