import 'package:flutter/material.dart';

class UpdateBanner extends StatelessWidget {
  final String version;
  final bool isWeb;
  final VoidCallback onTap;

  const UpdateBanner({
    super.key,
    required this.version,
    required this.isWeb,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: Material(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.rocket_launch_rounded, color: scheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'إصدار جديد $version متوفر',
                    style: TextStyle(
                      color: scheme.onPrimaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  isWeb ? 'تحديث' : 'تثبيت',
                  style: TextStyle(color: scheme.primary, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
