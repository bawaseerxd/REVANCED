import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:revanced_manager/ui/widgets/shared/custom_card.dart';

class LocalPatchSelectorCard extends StatelessWidget {
  const LocalPatchSelectorCard({
    super.key,
    required this.onPressed,
  });
  final Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: GestureDetector(
        onTap: onPressed,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            I18nText(
              'localPatchSelectorCard.selectLocalPatchesLabel',
              child: const Text(
                ' ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(height: 4),
            I18nText('localPatchSelectorCard.selectLocalPatchesText'),
          ],
        ),
      ),
    );
  }
}
