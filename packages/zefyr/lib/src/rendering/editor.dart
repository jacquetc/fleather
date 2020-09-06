import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:notus/notus.dart';

import 'editable_box.dart';

/// Signature for the callback that reports when the user changes the selection
/// (including the cursor location).
///
/// Used by [RenderEditor.onSelectionChanged].
typedef TextSelectionChangedHandler = void Function(
    TextSelection selection, SelectionChangedCause cause);

/// Base interface for any editable render object.
abstract class RenderAbstractEditor {
  TextSelection selectWordAtPosition(TextPosition position);
  TextSelection selectLineAtPosition(TextPosition position);

  /// Returns preferred line height at specified `position` in text.
  double preferredLineHeight(TextPosition position);

  Offset getOffsetForCaret(TextPosition position);
  TextPosition getPositionForOffset(Offset offset);

  /// Returns the local coordinates of the endpoints of the given selection.
  ///
  /// If the selection is collapsed (and therefore occupies a single point), the
  /// returned list is of length one. Otherwise, the selection is not collapsed
  /// and the returned list is of length two. In this case, however, the two
  /// points might actually be co-located (e.g., because of a bidirectional
  /// selection that contains some text but whose ends meet in the middle).
  List<TextSelectionPoint> getEndpointsForSelection(TextSelection selection);

  /// If [ignorePointer] is false (the default) then this method is called by
  /// the internal gesture recognizer's [TapGestureRecognizer.onTapDown]
  /// callback.
  ///
  /// When [ignorePointer] is true, an ancestor widget must respond to tap
  /// down events by calling this method.
  void handleTapDown(TapDownDetails details);

  /// Selects the set words of a paragraph in a given range of global positions.
  ///
  /// The first and last endpoints of the selection will always be at the
  /// beginning and end of a word respectively.
  ///
  /// {@macro flutter.rendering.editable.select}
  void selectWordsInRange({
    @required Offset from,
    Offset /*?*/ to,
    @required SelectionChangedCause cause,
  });

  /// Move the selection to the beginning or end of a word.
  ///
  /// {@macro flutter.rendering.editable.select}
  void selectWordEdge({@required SelectionChangedCause cause});

  /// Select text between the global positions [from] and [to].
  void selectPositionAt({
    @required Offset from,
    Offset /*?*/ to,
    @required SelectionChangedCause cause,
  });

  /// Select a word around the location of the last tap down.
  ///
  /// {@macro flutter.rendering.editable.select}
  void selectWord({@required SelectionChangedCause cause});

  /// Move selection to the location of the last tap down.
  ///
  /// {@template flutter.rendering.editable.select}
  /// This method is mainly used to translate user inputs in global positions
  /// into a [TextSelection]. When used in conjunction with a [EditableText],
  /// the selection change is fed back into [TextEditingController.selection].
  ///
  /// If you have a [TextEditingController], it's generally easier to
  /// programmatically manipulate its `value` or `selection` directly.
  /// {@endtemplate}
  void selectPosition({@required SelectionChangedCause cause});
}

/// Displays its children sequentially along a given axis, forcing them to the
/// dimensions of the parent in the other axis.
class RenderEditor extends RenderEditableContainerBox
    implements RenderAbstractEditor {
  RenderEditor({
    List<RenderEditableBox> children,
    @required NotusDocument document,
    @required TextDirection textDirection,
    @required bool hasFocus,
    @required TextSelection selection,
    @required LayerLink startHandleLayerLink,
    @required LayerLink endHandleLayerLink,
    TextSelectionChangedHandler onSelectionChanged,
    EdgeInsets floatingCursorAddedMargin =
        const EdgeInsets.fromLTRB(4, 4, 4, 5),
  })  : assert(document != null),
        assert(textDirection != null),
        assert(hasFocus != null),
        _document = document,
        _hasFocus = hasFocus,
        _selection = selection,
        _startHandleLayerLink = startHandleLayerLink,
        _endHandleLayerLink = endHandleLayerLink,
        onSelectionChanged = onSelectionChanged,
        super(
          children: children,
          node: document.root,
          textDirection: textDirection,
        );

  NotusDocument _document;
  set document(NotusDocument value) {
    assert(value != null);
    if (_document == value) {
      return;
    }
    _document = value;
    markNeedsLayout();
  }

  /// Whether the editor is currently focused.
  bool get hasFocus => _hasFocus;
  bool _hasFocus = false;
  set hasFocus(bool value) {
    assert(value != null);
    if (_hasFocus == value) {
      return;
    }
    _hasFocus = value;
    markNeedsSemanticsUpdate();
  }

  /// The region of text that is selected, if any.
  ///
  /// The caret position is represented by a collapsed selection.
  ///
  /// If [selection] is null, there is no selection and attempts to
  /// manipulate the selection will throw.
  TextSelection get selection => _selection;
  TextSelection _selection;
  set selection(TextSelection value) {
    if (_selection == value) return;
    _selection = value;
    markNeedsPaint();
  }

  /// The [LayerLink] of start selection handle.
  ///
  /// [RenderEditable] is responsible for calculating the [Offset] of this
  /// [LayerLink], which will be used as [CompositedTransformTarget] of start handle.
  LayerLink get startHandleLayerLink => _startHandleLayerLink;
  LayerLink _startHandleLayerLink;
  set startHandleLayerLink(LayerLink value) {
    if (_startHandleLayerLink == value) return;
    _startHandleLayerLink = value;
    markNeedsPaint();
  }

  /// The [LayerLink] of end selection handle.
  ///
  /// [RenderEditable] is responsible for calculating the [Offset] of this
  /// [LayerLink], which will be used as [CompositedTransformTarget] of end handle.
  LayerLink get endHandleLayerLink => _endHandleLayerLink;
  LayerLink _endHandleLayerLink;
  set endHandleLayerLink(LayerLink value) {
    if (_endHandleLayerLink == value) return;
    _endHandleLayerLink = value;
    markNeedsPaint();
  }

  /// Track whether position of the start of the selected text is within the viewport.
  ///
  /// For example, if the text contains "Hello World", and the user selects
  /// "Hello", then scrolls so only "World" is visible, this will become false.
  /// If the user scrolls back so that the "H" is visible again, this will
  /// become true.
  ///
  /// This bool indicates whether the text is scrolled so that the handle is
  /// inside the text field viewport, as opposed to whether it is actually
  /// visible on the screen.
  ValueListenable<bool> get selectionStartInViewport =>
      _selectionStartInViewport;
  final ValueNotifier<bool> _selectionStartInViewport =
      ValueNotifier<bool>(true);

  /// Track whether position of the end of the selected text is within the viewport.
  ///
  /// For example, if the text contains "Hello World", and the user selects
  /// "World", then scrolls so only "Hello" is visible, this will become
  /// 'false'. If the user scrolls back so that the "d" is visible again, this
  /// will become 'true'.
  ///
  /// This bool indicates whether the text is scrolled so that the handle is
  /// inside the text field viewport, as opposed to whether it is actually
  /// visible on the screen.
  ValueListenable<bool> get selectionEndInViewport => _selectionEndInViewport;
  final ValueNotifier<bool> _selectionEndInViewport = ValueNotifier<bool>(true);

  @override
  List<TextSelectionPoint> getEndpointsForSelection(TextSelection selection) {
    assert(constraints != null);
    // _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);

    TextSelection localSelection(
        RenderEditableBox box, TextSelection selection) {
      final documentOffset = box.node.documentOffset;
      final base = math.max(selection.start - documentOffset, 0);
      final extent =
          math.min(selection.end - documentOffset, box.node.length - 1);
      return selection.copyWith(
        baseOffset: base,
        extentOffset: extent,
      );
    }

    if (selection.isCollapsed) {
      final child = childAtPosition(selection.extent);
      final localPosition = TextPosition(
          offset: selection.extentOffset - child.node.documentOffset);
      final localOffset = child.getOffsetForCaret(localPosition);
      final BoxParentData parentData = child.parentData;
      final start = Offset(0.0, child.preferredLineHeight(localPosition)) +
          localOffset +
          parentData.offset;
      return <TextSelectionPoint>[TextSelectionPoint(start, null)];
    } else {
      final startChild = childAtPosition(TextPosition(offset: selection.start));
      final startSelection = localSelection(startChild, selection);
      final BoxParentData startParentData = startChild.parentData;
      Offset start;
      TextDirection startDirection;
      if (startSelection.isCollapsed) {
        final localOffset = startChild.getOffsetForCaret(startSelection.extent);
        start =
            Offset(0.0, startChild.preferredLineHeight(startSelection.extent)) +
                localOffset +
                startParentData.offset;
      } else {
        final startBoxes = startChild.getBoxesForSelection(startSelection);
        start = Offset(startBoxes.first.start, startBoxes.first.bottom) +
            startParentData.offset;
        startDirection = startBoxes.first.direction;
      }

      final endChild = childAtPosition(TextPosition(offset: selection.end));
      final BoxParentData endParentData = endChild.parentData;
      final endSelection = localSelection(endChild, selection);

      Offset end;
      TextDirection endDirection;
      if (endSelection.isCollapsed) {
        final localOffset = endChild.getOffsetForCaret(endSelection.extent);
        end = Offset(0.0, endChild.preferredLineHeight(endSelection.extent)) +
            localOffset +
            endParentData.offset;
      } else {
        final endBoxes = endChild.getBoxesForSelection(endSelection);
        end = Offset(endBoxes.last.end, endBoxes.last.bottom) +
            endParentData.offset;
        endDirection = endBoxes.last.direction;
      }

      return <TextSelectionPoint>[
        TextSelectionPoint(start, startDirection),
        TextSelectionPoint(end, endDirection),
      ];
    }
  }

  Offset /*?*/ _lastTapDownPosition;

  @override
  void handleTapDown(TapDownDetails details) {
    _lastTapDownPosition = details.globalPosition;
  }

  /// Called when the selection changes.
  ///
  /// If this is null, then selection changes will be ignored.
  TextSelectionChangedHandler /*?*/ onSelectionChanged;

  @override
  void selectWordsInRange({
    @required Offset from,
    Offset /*?*/ to,
    @required SelectionChangedCause cause,
  }) {
    assert(cause != null);
    assert(from != null);
    // _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    if (onSelectionChanged == null) {
      return;
    }
    final firstPosition = getPositionForOffset(from);
    final firstWord = selectWordAtPosition(firstPosition);
    final lastWord =
        to == null ? firstWord : selectWordAtPosition(getPositionForOffset(to));

    _handleSelectionChange(
      TextSelection(
        baseOffset: firstWord.base.offset,
        extentOffset: lastWord.extent.offset,
        affinity: firstWord.affinity,
      ),
      cause,
    );
  }

  @override
  void selectWordEdge({@required SelectionChangedCause cause}) {
    assert(cause != null);
    // _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    assert(_lastTapDownPosition != null);
    if (onSelectionChanged == null) {
      return;
    }
    final position = getPositionForOffset(_lastTapDownPosition);
    final child = childAtPosition(position);
    final documentOffset = child.node.documentOffset;
    final localPosition = TextPosition(
      offset: position.offset - documentOffset,
      affinity: position.affinity,
    );
    final localWord = child.getWordBoundary(localPosition);
    final word = TextRange(
      start: localWord.start + documentOffset,
      end: localWord.end + documentOffset,
    );
    if (position.offset - word.start <= 1) {
      _handleSelectionChange(
        TextSelection.collapsed(
            offset: word.start, affinity: TextAffinity.downstream),
        cause,
      );
    } else {
      _handleSelectionChange(
        TextSelection.collapsed(
            offset: word.end, affinity: TextAffinity.upstream),
        cause,
      );
    }
  }

  @override
  void selectPositionAt({
    @required Offset from,
    Offset /*?*/ to,
    @required SelectionChangedCause cause,
  }) {
    assert(cause != null);
    assert(from != null);
    // _layoutText(minWidth: constraints.minWidth, maxWidth: constraints.maxWidth);
    if (onSelectionChanged == null) {
      return;
    }
    final fromPosition = getPositionForOffset(from);
    final toPosition = to == null ? null : getPositionForOffset(to);

    var baseOffset = fromPosition.offset;
    var extentOffset = fromPosition.offset;
    if (toPosition != null) {
      baseOffset = math.min(fromPosition.offset, toPosition.offset);
      extentOffset = math.max(fromPosition.offset, toPosition.offset);
    }

    final newSelection = TextSelection(
      baseOffset: baseOffset,
      extentOffset: extentOffset,
      affinity: fromPosition.affinity,
    );
    // Call [onSelectionChanged] only when the selection actually changed.
    _handleSelectionChange(newSelection, cause);
  }

  @override
  void selectWord({@required SelectionChangedCause cause}) {
    selectWordsInRange(from: _lastTapDownPosition, cause: cause);
  }

  @override
  void selectPosition({@required SelectionChangedCause cause}) {
    selectPositionAt(from: _lastTapDownPosition, cause: cause);
  }

  @override
  TextSelection selectWordAtPosition(TextPosition position) {
//    assert(
//    _textLayoutLastMaxWidth == constraints.maxWidth &&
//        _textLayoutLastMinWidth == constraints.minWidth,
//    'Last width ($_textLayoutLastMinWidth, $_textLayoutLastMaxWidth) not the same as max width constraint (${constraints.minWidth}, ${constraints.maxWidth}).');
    final child = childAtPosition(position);
    final documentOffset = child.node.documentOffset;
    final localPosition = TextPosition(
        offset: position.offset - documentOffset, affinity: position.affinity);
    final localWord = child.getWordBoundary(localPosition);
    final word = TextRange(
      start: localWord.start + documentOffset,
      end: localWord.end + documentOffset,
    );
    // When long-pressing past the end of the text, we want a collapsed cursor.
    if (position.offset >= word.end) {
      return TextSelection.fromPosition(position);
    }
    return TextSelection(baseOffset: word.start, extentOffset: word.end);
  }

  @override
  TextSelection selectLineAtPosition(TextPosition position) {
//    assert(
//    _textLayoutLastMaxWidth == constraints.maxWidth &&
//        _textLayoutLastMinWidth == constraints.minWidth,
//    'Last width ($_textLayoutLastMinWidth, $_textLayoutLastMaxWidth) not the same as max width constraint (${constraints.minWidth}, ${constraints.maxWidth}).');
    final child = childAtPosition(position);
    final documentOffset = child.node.documentOffset;
    final localPosition = TextPosition(
        offset: position.offset - documentOffset, affinity: position.affinity);
    final localLineRange = child.getLineBoundary(localPosition);
    final line = TextRange(
      start: localLineRange.start + documentOffset,
      end: localLineRange.end + documentOffset,
    );

    // When long-pressing past the end of the text, we want a collapsed cursor.
    if (position.offset >= line.end) {
      return TextSelection.fromPosition(position);
    }
    return TextSelection(baseOffset: line.start, extentOffset: line.end);
  }

  // Call through to onSelectionChanged.
  void _handleSelectionChange(
    TextSelection nextSelection,
    SelectionChangedCause cause,
  ) {
    // Changes made by the keyboard can sometimes be "out of band" for listening
    // components, so always send those events, even if we didn't think it
    // changed. Also, focusing an empty field is sent as a selection change even
    // if the selection offset didn't change.
    final focusingEmpty = nextSelection.baseOffset == 0 &&
        nextSelection.extentOffset == 0 &&
        !hasFocus;
    if (nextSelection == selection &&
        cause != SelectionChangedCause.keyboard &&
        !focusingEmpty) {
      return;
    }
    if (onSelectionChanged != null) {
      onSelectionChanged(nextSelection, cause);
    }
  }

  // Start RenderBox implementation

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
//    _tap = TapGestureRecognizer(debugOwner: this)
//      ..onTapDown = _handleTapDown
//      ..onTap = _handleTap;
//    _longPress = LongPressGestureRecognizer(debugOwner: this)..onLongPress = _handleLongPress;
//    _offset.addListener(markNeedsPaint);
//    _showCursor.addListener(markNeedsPaint);
  }

  @override
  void detach() {
//    _tap.dispose();
//    _longPress.dispose();
//    _offset.removeListener(markNeedsPaint);
//    _showCursor.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    defaultPaint(context, offset);
    _paintHandleLayers(context, getEndpointsForSelection(selection));
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {Offset position}) {
    return defaultHitTestChildren(result, position: position);
  }

  void _paintHandleLayers(
      PaintingContext context, List<TextSelectionPoint> endpoints) {
    var startPoint = endpoints[0].point;
    startPoint = Offset(
      startPoint.dx.clamp(0.0, size.width),
      startPoint.dy.clamp(0.0, size.height),
    );
    context.pushLayer(
      LeaderLayer(link: startHandleLayerLink, offset: startPoint),
      super.paint,
      Offset.zero,
    );
    if (endpoints.length == 2) {
      var endPoint = endpoints[1].point;
      endPoint = Offset(
        endPoint.dx.clamp(0.0, size.width),
        endPoint.dy.clamp(0.0, size.height),
      );
      context.pushLayer(
        LeaderLayer(link: endHandleLayerLink, offset: endPoint),
        super.paint,
        Offset.zero,
      );
    }
  }

  @override
  double preferredLineHeight(TextPosition position) {
    final child = childAtPosition(position);
    final localPosition =
        TextPosition(offset: position.offset - child.node.offset);
    return child.preferredLineHeight(localPosition);
  }

  @override
  Offset getOffsetForCaret(TextPosition position) {
    final child = childAtPosition(position);
    final localPosition = TextPosition(
      offset: position.offset - child.node.documentOffset,
      affinity: position.affinity,
    );
    // TODO: this might need to shift the offset from the child's local coordinates.
    return childAtPosition(position).getOffsetForCaret(localPosition);
  }

  @override
  TextPosition getPositionForOffset(Offset offset) {
    final local = globalToLocal(offset);
    final child = childAtOffset(local);

    final BoxParentData parentData = child.parentData;
    final localOffset = local - parentData.offset;
    final localPosition = child.getPositionForOffset(localOffset);
    return TextPosition(
      offset: localPosition.offset + child.node.documentOffset,
      affinity: localPosition.affinity,
    );
  }
}
