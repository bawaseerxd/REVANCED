import 'package:flutter/material.dart';

class BooleanBox extends StatefulWidget {
  BooleanBox({
    Key? key,
    required this.isSelected,
  }) : super(key: key);
  bool isSelected;

  @override
  State<BooleanBox> createState() => _BooleanBoxState();
}

class _BooleanBoxState extends State<BooleanBox> {
  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    final width = MediaQuery.of(context).size.width;

    return Container(
      width: width * 0.29,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[700]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: <Widget>[
            GestureDetector(
              child: Container(
                height: height * 0.05,
                width: width * 0.12,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  ),
                  color: widget.isSelected
                      ? Colors.green[700]
                      : Colors.transparent,
                ),
                child: const Icon(Icons.check),
              ),
              onTap: () {
                setState(() {
                  widget.isSelected = !widget.isSelected;
                });
              },
            ),
            VerticalDivider(
              color: Colors.grey[700],
              thickness: 1,
            ),
            GestureDetector(
              child: Container(
                height: height * 0.05,
                width: width * 0.12,
                decoration: BoxDecoration(
                  color:
                      !widget.isSelected ? Colors.red[700] : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: const Icon(Icons.close),
              ),
              onTap: () {
                setState(() {
                  widget.isSelected = !widget.isSelected;
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}
