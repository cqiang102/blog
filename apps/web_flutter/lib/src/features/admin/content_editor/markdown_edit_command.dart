import 'package:flutter/services.dart';

enum MarkdownEditAction {
  bold,
  italic,
  strikethrough,
  heading1,
  heading2,
  heading3,
  heading4,
  heading5,
  heading6,
  unorderedList,
  orderedList,
  taskList,
  quote,
  inlineCode,
  link,
  horizontalRule,
  table2x2,
  table3x3,
  table4x4,
}

class MarkdownEditCommand {
  const MarkdownEditCommand._();

  static TextEditingValue apply(
    TextEditingValue value,
    MarkdownEditAction action,
  ) {
    return switch (action) {
      MarkdownEditAction.bold => bold(value),
      MarkdownEditAction.italic => italic(value),
      MarkdownEditAction.strikethrough => strikethrough(value),
      MarkdownEditAction.heading1 => heading(value, 1),
      MarkdownEditAction.heading2 => heading(value, 2),
      MarkdownEditAction.heading3 => heading(value, 3),
      MarkdownEditAction.heading4 => heading(value, 4),
      MarkdownEditAction.heading5 => heading(value, 5),
      MarkdownEditAction.heading6 => heading(value, 6),
      MarkdownEditAction.unorderedList => unorderedList(value),
      MarkdownEditAction.orderedList => orderedList(value),
      MarkdownEditAction.taskList => taskList(value),
      MarkdownEditAction.quote => quote(value),
      MarkdownEditAction.inlineCode => inlineCode(value),
      MarkdownEditAction.link => link(value),
      MarkdownEditAction.horizontalRule => horizontalRule(value),
      MarkdownEditAction.table2x2 => table(value, columns: 2, rows: 1),
      MarkdownEditAction.table3x3 => table(value, columns: 3, rows: 2),
      MarkdownEditAction.table4x4 => table(value, columns: 4, rows: 3),
    };
  }

  static TextEditingValue wrap(
    TextEditingValue value, {
    required String prefix,
    required String suffix,
    String placeholder = '',
  }) {
    final range = _selectionRange(value);
    final selected = value.text.substring(range.start, range.end);

    final outerStart = range.start - prefix.length;
    final outerEnd = range.end + suffix.length;
    final hasOuterWrapper =
        outerStart >= 0 &&
        outerEnd <= value.text.length &&
        value.text.substring(outerStart, range.start) == prefix &&
        value.text.substring(range.end, outerEnd) == suffix &&
        !_isAmbiguousSingleAsteriskWrapper(
          value.text,
          prefix: prefix,
          outerStart: outerStart,
          outerEnd: outerEnd,
        );
    if (hasOuterWrapper) {
      final nextText = value.text.replaceRange(outerStart, outerEnd, selected);
      return value.copyWith(
        text: nextText,
        selection: TextSelection(
          baseOffset: outerStart,
          extentOffset: outerStart + selected.length,
        ),
        composing: TextRange.empty,
      );
    }

    final selectionIncludesWrapper =
        selected.length >= prefix.length + suffix.length &&
        selected.startsWith(prefix) &&
        selected.endsWith(suffix) &&
        !(prefix == '*' && selected.startsWith('**'));
    if (selectionIncludesWrapper) {
      final inner = selected.substring(
        prefix.length,
        selected.length - suffix.length,
      );
      final nextText = value.text.replaceRange(range.start, range.end, inner);
      return value.copyWith(
        text: nextText,
        selection: TextSelection(
          baseOffset: range.start,
          extentOffset: range.start + inner.length,
        ),
        composing: TextRange.empty,
      );
    }

    final inner = selected.isEmpty ? placeholder : selected;
    final nextText = value.text.replaceRange(
      range.start,
      range.end,
      '$prefix$inner$suffix',
    );
    final selectionStart = range.start + prefix.length;
    final selectionEnd = selectionStart + inner.length;

    return value.copyWith(
      text: nextText,
      selection: inner.isEmpty
          ? TextSelection.collapsed(offset: selectionStart)
          : TextSelection(
              baseOffset: selectionStart,
              extentOffset: selectionEnd,
            ),
      composing: TextRange.empty,
    );
  }

  static TextEditingValue insert(
    TextEditingValue value,
    String text, {
    int? cursorOffset,
  }) {
    final range = _selectionRange(value);
    final nextText = value.text.replaceRange(range.start, range.end, text);
    return value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(
        offset: range.start + (cursorOffset ?? text.length),
      ),
      composing: TextRange.empty,
    );
  }

  static TextEditingValue replaceMarker(
    TextEditingValue value, {
    required String marker,
    required String replacement,
  }) {
    final markerStart = value.text.indexOf(marker);
    if (markerStart < 0) return value;
    final markerEnd = markerStart + marker.length;
    final nextText = value.text.replaceRange(
      markerStart,
      markerEnd,
      replacement,
    );
    final delta = replacement.length - marker.length;

    int mapOffset(int offset) {
      if (offset <= markerStart) return offset;
      if (offset >= markerEnd) return offset + delta;
      return markerStart + replacement.length;
    }

    final selection = value.selection;
    return value.copyWith(
      text: nextText,
      selection: selection.isValid
          ? TextSelection(
              baseOffset: mapOffset(selection.baseOffset),
              extentOffset: mapOffset(selection.extentOffset),
              affinity: selection.affinity,
              isDirectional: selection.isDirectional,
            )
          : TextSelection.collapsed(offset: nextText.length),
      composing: TextRange.empty,
    );
  }

  static TextEditingValue bold(TextEditingValue value) =>
      wrap(value, prefix: '**', suffix: '**', placeholder: '粗体文字');

  static TextEditingValue italic(TextEditingValue value) =>
      wrap(value, prefix: '*', suffix: '*', placeholder: '斜体文字');

  static TextEditingValue strikethrough(TextEditingValue value) =>
      wrap(value, prefix: '~~', suffix: '~~', placeholder: '删除线文字');

  static TextEditingValue inlineCode(TextEditingValue value) =>
      wrap(value, prefix: '`', suffix: '`', placeholder: 'code');

  static TextEditingValue heading(TextEditingValue value, int level) {
    final safeLevel = level.clamp(1, 6);
    final marker = '${'#' * safeLevel} ';
    final lines = _selectedLines(value);
    final headingPattern = RegExp(r'^(\s{0,3})(#{1,6})\s+(.*)$');
    final removeHeading = lines.every((line) {
      final match = headingPattern.firstMatch(line);
      return match != null && match.group(2)!.length == safeLevel;
    });

    return _transformSelectedLines(value, (line, _) {
      final match = headingPattern.firstMatch(line);
      final indentation = match?.group(1) ?? '';
      final content = match?.group(3) ?? line.substring(indentation.length);
      if (removeHeading) return '$indentation$content';
      return '$indentation$marker$content';
    });
  }

  static TextEditingValue link(TextEditingValue value) {
    final range = _selectionRange(value);
    final selected = value.text.substring(range.start, range.end);
    final label = selected.isEmpty ? '链接文字' : selected;
    final next = '[$label](url)';
    final nextText = value.text.replaceRange(range.start, range.end, next);
    final urlStart = range.start + label.length + 3;

    return value.copyWith(
      text: nextText,
      selection: TextSelection(
        baseOffset: urlStart,
        extentOffset: urlStart + 3,
      ),
      composing: TextRange.empty,
    );
  }

  static TextEditingValue image(TextEditingValue value, {required String url}) {
    final range = _selectionRange(value);
    final selected = value.text.substring(range.start, range.end).trim();
    final alt = selected.isEmpty ? '图片描述' : selected;
    final markdown = '![$alt]($url)';
    final nextText = value.text.replaceRange(range.start, range.end, markdown);
    final altStart = range.start + 2;
    return value.copyWith(
      text: nextText,
      selection: TextSelection(
        baseOffset: altStart,
        extentOffset: altStart + alt.length,
      ),
      composing: TextRange.empty,
    );
  }

  static TextEditingValue codeBlock(
    TextEditingValue value, {
    String language = '',
  }) {
    final range = _selectionRange(value);
    final currentFence = _currentFence(value.text, range.start);
    if (currentFence != null) {
      final nextText = value.text.replaceRange(
        currentFence.languageStart,
        currentFence.languageEnd,
        language,
      );
      return value.copyWith(
        text: nextText,
        selection: TextSelection.collapsed(
          offset: currentFence.languageStart + language.length,
        ),
        composing: TextRange.empty,
      );
    }

    final selected = value.text.substring(range.start, range.end);
    final code = selected;
    final closingLineBreak = code.isEmpty || !code.endsWith('\n') ? '\n' : '';
    final block = '\n```$language\n$code$closingLineBreak```\n';
    final cursorOffset = code.isEmpty
        ? 5 + language.length
        : block.indexOf(code) + code.length;
    return insert(value, block, cursorOffset: cursorOffset);
  }

  static TextEditingValue quote(TextEditingValue value) =>
      _toggleLinePrefix(value, '> ');

  static TextEditingValue unorderedList(TextEditingValue value) =>
      _toggleLinePrefix(value, '- ');

  static TextEditingValue orderedList(TextEditingValue value) {
    final orderedPattern = RegExp(r'^\s*\d+\.\s+');
    final removeMarkers = _selectedLines(value).every(orderedPattern.hasMatch);
    return _transformSelectedLines(value, (line, index) {
      final stripped = line.replaceFirst(RegExp(r'^\s*\d+\.\s+'), '');
      if (removeMarkers) return stripped;
      return '${index + 1}. $stripped';
    });
  }

  static TextEditingValue taskList(TextEditingValue value) =>
      _toggleLinePrefix(value, '- [ ] ');

  static TextEditingValue horizontalRule(TextEditingValue value) =>
      insert(value, '\n\n---\n\n');

  static TextEditingValue table(
    TextEditingValue value, {
    required int columns,
    required int rows,
  }) {
    final safeColumns = columns.clamp(1, 8);
    final safeRows = rows.clamp(1, 12);
    final headers = List.generate(safeColumns, (index) => '列${index + 1}');
    final separator = List.filled(safeColumns, '---');
    final bodyRows = List.generate(
      safeRows,
      (_) => List.filled(safeColumns, '内容'),
    );
    String row(List<String> cells) => '| ${cells.join(' | ')} |';
    final markdown = [
      '',
      row(headers),
      row(separator),
      for (final bodyRow in bodyRows) row(bodyRow),
      '',
    ].join('\n');
    return insert(value, markdown);
  }

  static TextEditingValue? autocomplete({
    required String previousText,
    required TextEditingValue value,
  }) {
    final selection = value.selection;
    if (!selection.isCollapsed || selection.start <= 0) return null;

    final inserted = _singleInsertedText(
      previousText,
      value.text,
      selection.end,
    );
    if (inserted == null) return null;

    return switch (inserted) {
      '[' =>
        _isInsideCodeFenceAt(value.text, selection.end - 1) ||
                _isInsideInlineCodeAt(value.text, selection.end - 1)
            ? null
            : _completeLinkBrackets(value),
      '\n' => _completeNewLine(value),
      _ => null,
    };
  }

  static _TextRange _selectionRange(TextEditingValue value) {
    final textLength = value.text.length;
    final selection = value.selection;
    if (!selection.isValid) {
      return _TextRange(textLength, textLength);
    }
    final start = selection.start.clamp(0, textLength);
    final end = selection.end.clamp(0, textLength);
    return _TextRange(start < end ? start : end, start < end ? end : start);
  }

  static TextEditingValue _toggleLinePrefix(
    TextEditingValue value,
    String prefix,
  ) {
    final removePrefix = _selectedLines(
      value,
    ).every((line) => line.startsWith(prefix));
    return _transformSelectedLines(value, (line, _) {
      if (removePrefix) return line.substring(prefix.length);
      if (line.startsWith(prefix)) return line;
      return '$prefix$line';
    });
  }

  static List<String> _selectedLines(TextEditingValue value) {
    final range = _selectionRange(value);
    final lineStart = _lineStartAt(value.text, range.start);
    final selectionEnd =
        range.end > range.start &&
            range.end > 0 &&
            value.text[range.end - 1] == '\n'
        ? range.end - 1
        : range.end;
    final nextLineBreak = value.text.indexOf('\n', selectionEnd);
    final lineEnd = nextLineBreak == -1 ? value.text.length : nextLineBreak;
    return value.text.substring(lineStart, lineEnd).split('\n');
  }

  static TextEditingValue _transformSelectedLines(
    TextEditingValue value,
    String Function(String line, int index) transform,
  ) {
    final range = _selectionRange(value);
    final lineStart = _lineStartAt(value.text, range.start);
    final selectionEnd =
        range.end > range.start &&
            range.end > 0 &&
            value.text[range.end - 1] == '\n'
        ? range.end - 1
        : range.end;
    final nextLineBreak = value.text.indexOf('\n', selectionEnd);
    final lineEnd = nextLineBreak == -1 ? value.text.length : nextLineBreak;
    final selectedBlock = value.text.substring(lineStart, lineEnd);
    final lines = selectedBlock.split('\n');
    final nextBlock = [
      for (var index = 0; index < lines.length; index++)
        transform(lines[index], index),
    ].join('\n');
    final nextText = value.text.replaceRange(lineStart, lineEnd, nextBlock);
    final delta = nextBlock.length - selectedBlock.length;

    int mapOffset(int offset) {
      if (offset < lineStart) return offset;
      if (offset > lineEnd) return offset + delta;

      final relativeOffset = offset - lineStart;
      var oldLineStart = 0;
      var newLineStart = 0;
      for (var index = 0; index < lines.length; index++) {
        final oldLine = lines[index];
        final newLine = transform(oldLine, index);
        final oldLineEnd = oldLineStart + oldLine.length;
        if (relativeOffset <= oldLineEnd) {
          final oldColumn = relativeOffset - oldLineStart;
          return lineStart +
              newLineStart +
              _mapTransformedColumn(oldLine, newLine, oldColumn);
        }
        oldLineStart = oldLineEnd + 1;
        newLineStart += newLine.length + 1;
      }
      return lineStart + nextBlock.length;
    }

    final selection = value.selection;
    final nextSelection = selection.isValid
        ? TextSelection(
            baseOffset: mapOffset(
              selection.baseOffset,
            ).clamp(0, nextText.length).toInt(),
            extentOffset: mapOffset(
              selection.extentOffset,
            ).clamp(0, nextText.length).toInt(),
            affinity: selection.affinity,
            isDirectional: selection.isDirectional,
          )
        : TextSelection.collapsed(offset: nextText.length);

    return value.copyWith(
      text: nextText,
      selection: nextSelection,
      composing: TextRange.empty,
    );
  }

  static int _mapTransformedColumn(
    String oldLine,
    String newLine,
    int oldColumn,
  ) {
    var commonSuffixLength = 0;
    while (commonSuffixLength < oldLine.length &&
        commonSuffixLength < newLine.length &&
        oldLine[oldLine.length - commonSuffixLength - 1] ==
            newLine[newLine.length - commonSuffixLength - 1]) {
      commonSuffixLength++;
    }

    final oldPrefixLength = oldLine.length - commonSuffixLength;
    final newPrefixLength = newLine.length - commonSuffixLength;
    if (oldColumn < oldPrefixLength) {
      return oldColumn.clamp(0, newPrefixLength).toInt();
    }
    return (newPrefixLength + oldColumn - oldPrefixLength)
        .clamp(0, newLine.length)
        .toInt();
  }

  static bool _isAmbiguousSingleAsteriskWrapper(
    String text, {
    required String prefix,
    required int outerStart,
    required int outerEnd,
  }) {
    if (prefix != '*') return false;
    final touchesLeadingAsterisk =
        outerStart > 0 && text[outerStart - 1] == '*';
    final touchesTrailingAsterisk =
        outerEnd < text.length && text[outerEnd] == '*';
    return touchesLeadingAsterisk || touchesTrailingAsterisk;
  }

  static TextEditingValue? _completeLinkBrackets(TextEditingValue value) {
    final offset = value.selection.end;
    final beforeBracket = value.text.substring(0, offset - 1);
    final lineStart = beforeBracket.lastIndexOf('\n') + 1;
    final currentLine = beforeBracket.substring(lineStart);
    if (currentLine.endsWith('\\') ||
        RegExp(r'^\s*[-*+]\s+$').hasMatch(currentLine)) {
      return null;
    }
    final nextText = value.text.replaceRange(offset, offset, ']()');
    return value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }

  static TextEditingValue? _completeNewLine(TextEditingValue value) {
    final offset = value.selection.end;
    final previousLineEnd = offset - 1;
    final previousLineStart = _lineStartAt(value.text, previousLineEnd);
    final previousLine = value.text.substring(
      previousLineStart,
      previousLineEnd,
    );

    final fenceMatch = RegExp(
      r'^(\s*)(`{3,}|~{3,})[^`~]*$',
    ).firstMatch(previousLine);
    final insideFenceBeforeLine = _isInsideCodeFenceAt(
      value.text,
      previousLineStart,
    );
    if (fenceMatch != null && !insideFenceBeforeLine) {
      final closingFence = '${fenceMatch.group(1)!}${fenceMatch.group(2)!}';
      final nextText = value.text.replaceRange(
        offset,
        offset,
        '\n$closingFence',
      );
      return value.copyWith(
        text: nextText,
        selection: TextSelection.collapsed(offset: offset),
        composing: TextRange.empty,
      );
    }
    if (insideFenceBeforeLine) return null;

    final emptyMarker = RegExp(r'^(\s*)(?:[-*+]|\d+\.|>\s?|- \[[ xX]\])\s*$');
    if (emptyMarker.hasMatch(previousLine)) {
      final nextText = value.text.replaceRange(previousLineStart, offset, '');
      return value.copyWith(
        text: nextText,
        selection: TextSelection.collapsed(offset: previousLineStart),
        composing: TextRange.empty,
      );
    }

    final taskMatch = RegExp(r'^(\s*)- \[[ xX]\]\s+').firstMatch(previousLine);
    if (taskMatch != null) {
      return _insertAfterNewline(value, '${taskMatch.group(1)!}- [ ] ');
    }

    final unorderedMatch = RegExp(r'^(\s*)[-*+]\s+').firstMatch(previousLine);
    if (unorderedMatch != null) {
      return _insertAfterNewline(value, '${unorderedMatch.group(1)!}- ');
    }

    final orderedMatch = RegExp(r'^(\s*)(\d+)\.\s+').firstMatch(previousLine);
    if (orderedMatch != null) {
      final number = int.tryParse(orderedMatch.group(2)!) ?? 1;
      return _insertAfterNewline(
        value,
        '${orderedMatch.group(1)!}${number + 1}. ',
      );
    }

    final quoteMatch = RegExp(r'^(\s*)>\s+').firstMatch(previousLine);
    if (quoteMatch != null) {
      return _insertAfterNewline(value, '${quoteMatch.group(1)!}> ');
    }

    if (_looksLikeTableRow(previousLine)) {
      final columns = '|'.allMatches(previousLine).length - 1;
      if (columns > 0) {
        return _insertAfterNewline(
          value,
          '| ${List.filled(columns, '').join(' | ')} |',
        );
      }
    }

    return null;
  }

  static bool _isInsideCodeFenceAt(String text, int offset) {
    final safeOffset = offset.clamp(0, text.length).toInt();
    final prefix = text.substring(0, safeOffset);
    String? openMarker;
    for (final match in RegExp(
      r'^\s*(`{3,}|~{3,})',
      multiLine: true,
    ).allMatches(prefix)) {
      final marker = match.group(1)!;
      final markerType = marker[0];
      if (openMarker == null) {
        openMarker = markerType;
      } else if (openMarker == markerType) {
        openMarker = null;
      }
    }
    return openMarker != null;
  }

  static bool _isInsideInlineCodeAt(String text, int offset) {
    final safeOffset = offset.clamp(0, text.length).toInt();
    final lineStart = _lineStartAt(text, safeOffset);
    final line = text.substring(lineStart, safeOffset);
    var backtickCount = 0;
    for (var index = 0; index < line.length; index++) {
      if (line[index] == '`' && (index == 0 || line[index - 1] != '\\')) {
        backtickCount++;
      }
    }
    return backtickCount.isOdd;
  }

  static int _lineStartAt(String text, int offset) {
    if (offset <= 0 || text.isEmpty) return 0;
    final searchFrom = (offset - 1).clamp(0, text.length - 1).toInt();
    return text.lastIndexOf('\n', searchFrom) + 1;
  }

  static TextEditingValue _insertAfterNewline(
    TextEditingValue value,
    String insertion,
  ) {
    final offset = value.selection.end;
    final nextText = value.text.replaceRange(offset, offset, insertion);
    return value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: offset + insertion.length),
      composing: TextRange.empty,
    );
  }

  static bool _looksLikeTableRow(String line) {
    final trimmed = line.trim();
    if (!trimmed.startsWith('|') || !trimmed.endsWith('|')) return false;
    if (!trimmed.contains('---')) return true;
    return RegExp(r'^\|?[\s:-]+\|[\s|:-]*$').hasMatch(trimmed);
  }

  static String? _singleInsertedText(
    String previousText,
    String nextText,
    int insertionEnd,
  ) {
    if (nextText.length != previousText.length + 1) return null;
    final insertionStart = insertionEnd - 1;
    if (insertionStart < 0 || insertionEnd > nextText.length) return null;
    final inserted = nextText.substring(insertionStart, insertionEnd);
    final reconstructed =
        nextText.substring(0, insertionStart) +
        nextText.substring(insertionEnd);
    return reconstructed == previousText ? inserted : null;
  }

  static _CodeFenceRange? _currentFence(String text, int offset) {
    final matches = RegExp(
      r'(^|\n)(```|~~~)([^\n]*)',
      multiLine: true,
    ).allMatches(text).toList();
    _CodeFenceRange? openFence;

    for (final match in matches) {
      final fenceStart = match.start + (match.group(1)?.length ?? 0);
      final fenceEnd = match.end;
      if (fenceStart > offset) break;

      if (openFence == null) {
        openFence = _CodeFenceRange(
          start: fenceStart,
          end: fenceEnd,
          languageStart: fenceStart + 3,
          languageEnd: fenceEnd,
        );
      } else {
        if (offset <= fenceEnd) return openFence;
        openFence = null;
      }
    }

    return openFence;
  }
}

class _TextRange {
  const _TextRange(this.start, this.end);

  final int start;
  final int end;
}

class _CodeFenceRange {
  const _CodeFenceRange({
    required this.start,
    required this.end,
    required this.languageStart,
    required this.languageEnd,
  });

  final int start;
  final int end;
  final int languageStart;
  final int languageEnd;
}
