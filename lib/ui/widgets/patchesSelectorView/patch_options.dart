import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:revanced_manager/ui/widgets/patchesSelectorView/boolean_box.dart';

class StringOption extends StatelessWidget {
  const StringOption({super.key, required this.hint});
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        decoration: InputDecoration(
          isDense: true,
          border: const OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(12.0)),
          ),
          labelText: hint,
        ),
      ),
    );
  }
}

class PathOption extends StatelessWidget {
  const PathOption({super.key, required this.hint, required this.pathOption});
  final String hint;
  final String pathOption;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ButtonStyle(
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
          ),
        ),
        onPressed: () {
          // pick files
          final path = FilePicker.platform.getDirectoryPath();
        },
        child: Text(hint),
      ),
    );
  }
}

class BooleanOption extends StatelessWidget {
  const BooleanOption({super.key});
  final bool isSelected = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Some boolean toggle'),
          BooleanBox(isSelected: isSelected),
        ],
      ),
    );
  }
}

class StringListOption extends StatelessWidget {
  const StringListOption({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Some list options'),
          // show popup with list of options
          PopupMenuButton(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                child: Text('Option 1'),
              ),
              const PopupMenuItem(
                child: Text('Option 2'),
              ),
              const PopupMenuItem(
                child: Text('Option 3'),
              ),
            ],
            onSelected: (value) {
              // do something
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[700]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Select option'),
            ),
          ),
        ],
      ),
    );
  }
}

class IntListOption extends StatelessWidget {
  const IntListOption({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Some list options'),
          // show popup with list of options
          PopupMenuButton(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.0),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                child: Text('Option 1'),
              ),
              const PopupMenuItem(
                child: Text('Option 2'),
              ),
              const PopupMenuItem(
                child: Text('Option 3'),
              ),
            ],
            onSelected: (value) {
              // do something
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[700]!),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('Select option'),
            ),
          ),
        ],
      ),
    );
  }
}
