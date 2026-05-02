import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class AppointmentCard extends StatelessWidget {
  final String doctorName;
  final DateTime date;
  final String? notes;
  final String status;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final VoidCallback? onCancel;

  const AppointmentCard({
    super.key,
    required this.doctorName,
    required this.date,
    this.notes,
    this.status = 'pending',
    this.onTap,
    this.onDelete,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isPast = date.isBefore(DateTime.now());

    Color statusColor;
    switch (status) {
      case 'confirmed':
        statusColor = AppColors.success;
        break;
      case 'completed':
        statusColor = AppColors.info;
        break;
      case 'cancelled':
        statusColor = AppColors.danger;
        break;
      default:
        statusColor = AppColors.warning;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPast
                ? Colors.grey.withValues(alpha: 0.2)
                : AppColors.primary.withValues(alpha: 0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Date block
            Container(
              width: 52,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isPast
                    ? Colors.grey.withValues(alpha: 0.1)
                    : AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    DateFormat('d').format(date),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isPast ? Colors.grey : AppColors.primary,
                    ),
                  ),
                  Text(
                    DateFormat('MMM').format(date).toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isPast ? Colors.grey : AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    DateFormat('EEEE, h:mm a').format(date),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (notes != null && notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notes!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      status[0].toUpperCase() + status.substring(1),
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                if (onDelete != null)
                  GestureDetector(
                    onTap: onDelete,
                    child: const Icon(Icons.delete_outline,
                        color: AppColors.danger, size: 20),
                  ),
                if (onCancel != null && (status == 'pending' || status == 'confirmed')) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: onCancel,
                    child: const Text(
                      'Cancel',
                      style: TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

