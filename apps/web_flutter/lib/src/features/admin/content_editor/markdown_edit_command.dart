import 'package:flutter/services.dart';

class MarkdownEditCommand {
  const MarkdownEditCommand._();

  static TextEditingValue wrap(
    TextEditingValue value, {
    required String prefix,
    required String suffix,
    String placeholder = '',
  }) {
    final range = _selectionRange(value);
    final selected = value.text.substring(range.start, range.end);
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

  static TextEditingValue bold(TextEditingValue value) =>
      wrap(value, prefix: '**', suffix: '**', placeholder: '粗体文字');

  static TextEditingValue italic(TextEditingValue value) =>
      wrap(value, prefix: '*', suffix: '*', placeholder: '斜体文字');

  static TextEditingValue strikethrough(TextEditingValue value) =>
      wrap(value, prefix: '~~', suffix: '~~', placeholder: '删除线文字');

  static TextEditingValue inlineCode(TextEditingValue value) =>
      wrap(value, prefix: '`', suffix: '`', placeholder: 'code');

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
    final code = selected.isEmpty ? '' : selected.trimRight();
    final block = '\n```$language\n$code\n```\n';
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
    return _transformSelectedLines(value, (line, index) {
      final stripped = line.replaceFirst(RegExp(r'^\s*\d+\.\s+'), '');
      return '${index + 1}. $stripped';
    });
  }

  static TextEditingValue taskList(TextEditingValue value) =>
      _toggleLinePrefix(value, '- [ ] ');

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
      '[' => _completeLinkBrackets(value),
      '`' => _completeCodeFence(value),
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
    return _transformSelectedLines(value, (line, _) {
      if (line.startsWith(prefix)) return line.substring(prefix.length);
      return '$prefix$line';
    });
  }

  static TextEditingValue _transformSelectedLines(
    TextEditingValue value,
    String Function(String line, int index) transform,
  ) {
    final range = _selectionRange(value);
    final lineStart = value.text.lastIndexOf('\n', range.start - 1) + 1;
    final nextLineBreak = value.text.indexOf('\n', range.end);
    final lineEnd = nextLineBreak == -1 ? value.text.length : nextLineBreak;
    final selectedBlock = value.text.substring(lineStart, lineEnd);
    final lines = selectedBlock.split('\n');
    final nextBlock = [
      for (var index = 0; index < lines.length; index++)
        transform(lines[index], index),
    ].join('\n');
    final nextText = value.text.replaceRange(lineStart, lineEnd, nextBlock);
    final delta = nextBlock.length - selectedBlock.length;

    return value.copyWith(
      text: nextText,
      selection: TextSelection(
        baseOffset: range.start + (range.start == lineStart ? 0 : delta),
        extentOffset: range.end + delta,
      ),
      composing: TextRange.empty,
    );
  }

  static TextEditingValue? _completeLinkBrackets(TextEditingValue value) {
    final offset = value.selection.end;
    final nextText = value.text.replaceRange(offset, offset, ']()');
    return value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: offset),
      composing: TextRange.empty,
    );
  }

  static TextEditingValue? _completeCodeFence(TextEditingValue value) {
    final offset = value.selection.end;
    final before = value.text.substring(0, offset);
    final lineStart = before.lastIndexOf('\n') + 1;
    final currentLine = before.substring(lineStart);
    if (currentLine != '```') return null;

    final nextText = value.text.replaceRange(offset, offset, '\n\n```');
    return value.copyWith(
      text: nextText,
      selection: TextSelection.collapsed(offset: offset + 1),
      composing: TextRange.empty,
    );
  }

  static TextEditingValue? _completeNewLine(TextEditingValue value) {
    final offset = value.selection.end;
    final previousLineEnd = offset - 1;
    final previousLineStart =
        value.text.lastIndexOf('\n', previousLineEnd - 1) + 1;
    final previousLine = value.text.substring(
      previousLineStart,
      previousLineEnd,
    );

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
