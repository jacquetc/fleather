import 'package:flutter/material.dart';
import 'package:notus/notus.dart';

import '../rendering/editable_box.dart';
import '_cursor.dart';
import '_text_line.dart';

/// Line of editable text in Zefyr editor.
///
/// This widget adds editing features to the otherwise static [TextLine] widget.
class EditableTextLine extends SingleChildRenderObjectWidget {
  final LineNode node;
  final EdgeInsetsGeometry padding;
  final TextDirection textDirection;
  final CursorController cursorController;
  final TextSelection selection;
  final Color selectionColor;
  final bool enableInteractiveSelection;

  /// Creates an editable line of text represented by [node].
  EditableTextLine({
    Key key,
    @required this.node,
    @required this.padding,
    this.textDirection,
    @required TextLine child,
    @required this.cursorController,
    @required this.selection,
    @required this.selectionColor,
    @required this.enableInteractiveSelection,
  })  : assert(node != null),
        assert(padding != null),
        assert(child != null),
        assert(cursorController != null),
        assert(selection != null),
        assert(selectionColor != null),
        assert(enableInteractiveSelection != null),
        super(key: key, child: child);

  @override
  RenderEditableSingleChildBox createRenderObject(BuildContext context) {
    return RenderEditableSingleChildBox(
      node: node,
      padding: padding,
      textDirection: textDirection,
      cursorController: cursorController,
      selection: selection,
      selectionColor: selectionColor,
      enableInteractiveSelection: enableInteractiveSelection,
    );
  }

  @override
  void updateRenderObject(BuildContext context,
      covariant RenderEditableSingleChildBox renderObject) {
    renderObject.node = node;
    renderObject.padding = padding;
    renderObject.textDirection = textDirection;
    renderObject.cursorController = cursorController;
    renderObject.selection = selection;
    renderObject.selectionColor = selectionColor;
    renderObject.enableInteractiveSelection = enableInteractiveSelection;
  }
}
