import 'package:flutter/material.dart';
import 'login.dart' show AppColors;

// ─── Shared dialog/UI helpers ─────────────────────────────────────────────
// Extracted into their own file so collections.dart and items.dart can import
// them freely. Dart _private symbols cannot cross file boundaries.

/// Uppercase micro-label above a form field.
Widget dlgLabel(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 6),
  child: Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: AppColors.textMuted,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.1,
      fontFamily: 'SquadaOne',
    ),
  ),
);

/// Dark styled text field used inside dialogs.
Widget dlgTextField(TextEditingController ctrl, String hint) => TextField(
  controller: ctrl,
  style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
  decoration: InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
    filled: true,
    fillColor: const Color(0x990A0A19),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accentBorder, width: 1)),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accentBorder, width: 1)),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.accent, width: 1.5)),
  ),
);

/// Small square icon button with accent tint — used next to criteria input.
Widget accentIconButton(IconData icon, VoidCallback onTap) => InkWell(
  onTap: onTap,
  borderRadius: BorderRadius.circular(8),
  child: Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: AppColors.accentDim,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppColors.accentBorder, width: 1),
    ),
    child: Icon(icon, color: AppColors.accent, size: 18),
  ),
);

/// Pill chip showing a criterion with an × remove button.
Widget criteriaChip(String label, VoidCallback onRemove) => Container(
  padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
  decoration: BoxDecoration(
    color: AppColors.accentDim,
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.accentBorder, width: 1),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label,
          style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontFamily: 'SquadaOne')),
      const SizedBox(width: 4),
      GestureDetector(
        onTap: onRemove,
        child: const Icon(Icons.close, size: 14, color: AppColors.textMuted),
      ),
    ],
  ),
);

/// Muted "Cancel" text button for dialog actions.
Widget dlgCancelBtn(BuildContext ctx) => TextButton(
  onPressed: () => Navigator.pop(ctx),
  child: const Text('Cancel',
      style: TextStyle(
          color: AppColors.textSecondary, fontFamily: 'SquadaOne')),
);

/// Accent-coloured confirm text button for dialog actions.
Widget dlgConfirmBtn(String label, VoidCallback onPressed) => TextButton(
  onPressed: onPressed,
  child: Text(label,
      style: const TextStyle(
          color: AppColors.accent,
          fontFamily: 'SquadaOne',
          fontWeight: FontWeight.w700)),
);

/// Enhanced breadcrumb row with navigation support.
/// Each [BreadcrumbItem] can have an optional [onTap] callback.
class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;
  
  BreadcrumbItem({required this.label, this.onTap});
}

Widget buildBreadcrumb(List<BreadcrumbItem> parts) => Padding(
  padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
  child: Align(
    alignment: Alignment.centerLeft,
    child: Row(
      children: parts
          .expand((p) => [
                GestureDetector(
                  onTap: p.onTap,
                  child: Text(
                    p.label,
                    style: TextStyle(
                      color: p.onTap != null ? AppColors.accent : AppColors.textMuted,
                      fontSize: 16,
                      fontFamily: 'SquadaOne',
                      letterSpacing: 0.5,
                      fontWeight: p.onTap != null ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (p != parts.last)
                  const Text(' > ',
                      style: TextStyle(
                          color: AppColors.borderSubtle, fontSize: 16)),
              ])
          .toList(),
    ),
  ),
);
