import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:revanced_manager/app/app.locator.dart';
import 'package:revanced_manager/ui/views/patcher/patcher_viewmodel.dart';
import 'package:revanced_manager/ui/widgets/shared/custom_card.dart';

class PatchBundleSelectorCard extends StatelessWidget {
  final Function() onPressed;

  const PatchBundleSelectorCard({
    Key? key,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      onTap: onPressed,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          I18nText(
            locator<PatcherViewModel>().selectedApp == null
                ? 'patchBundleSelectorCard.widgetTitle'
                : 'patchBundleSelectorCard.widgetTitleSelected',
            child: const Text(
              '',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 8),
          locator<PatcherViewModel>().selectedApp == null
              ? I18nText('patchBundleSelectorCard.widgetSubtitle')
              : Row(
                  children: const <Widget>[
                    Text(
                      "No patch bundle selected",
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ],
      ),
    );
  }
}
