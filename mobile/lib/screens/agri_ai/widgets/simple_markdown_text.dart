import 'package:flutter/material.dart';

/// A small, dependency-free renderer for the light markdown Gemini tends to
/// reply with (bold labels, bullet/numbered lists, "### " section headers) —
/// just enough so FloraAI's structured plant-care advice reads as formatted
/// text instead of literal asterisks and dashes, without pulling in a full
/// markdown package for one screen.
class SimpleMarkdownText extends StatelessWidget {
  const SimpleMarkdownText({
    super.key,
    required this.text,
    required this.style,
  });

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    final blocks = <Widget>[];
    var isFirst = true;

    for (final rawLine in lines) {
      final line = rawLine.trimRight();
      if (line.trim().isEmpty) continue;

      final spacing = isFirst ? 0.0 : 6.0;
      isFirst = false;

      final headerMatch = RegExp(r'^#{1,6}\s+(.*)').firstMatch(line);
      final bulletMatch = RegExp(r'^[-*]\s+(.*)').firstMatch(line);
      final numberedMatch = RegExp(r'^(\d+)\.\s+(.*)').firstMatch(line);

      if (headerMatch != null) {
        blocks.add(Padding(
          padding: EdgeInsets.only(top: spacing, bottom: 2),
          child: _richText(
            headerMatch.group(1)!,
            style.copyWith(fontWeight: FontWeight.w800, fontSize: style.fontSize! + 1),
          ),
        ));
      } else if (bulletMatch != null) {
        blocks.add(Padding(
          padding: EdgeInsets.only(top: spacing),
          child: _bulletLine('•', bulletMatch.group(1)!, style),
        ));
      } else if (numberedMatch != null) {
        blocks.add(Padding(
          padding: EdgeInsets.only(top: spacing),
          child: _bulletLine('${numberedMatch.group(1)}.', numberedMatch.group(2)!, style),
        ));
      } else {
        blocks.add(Padding(
          padding: EdgeInsets.only(top: spacing),
          child: _richText(line, style),
        ));
      }
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: blocks);
  }

  Widget _bulletLine(String marker, String text, TextStyle style) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20,
          child: Text(marker, style: style.copyWith(fontWeight: FontWeight.w700)),
        ),
        Expanded(child: _richText(text, style)),
      ],
    );
  }

  /// Handles inline `**bold**` spans within an otherwise plain line.
  Widget _richText(String line, TextStyle style) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var cursor = 0;

    for (final match in pattern.allMatches(line)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: line.substring(cursor, match.start), style: style));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: style.copyWith(fontWeight: FontWeight.w700),
      ));
      cursor = match.end;
    }
    if (cursor < line.length) {
      spans.add(TextSpan(text: line.substring(cursor), style: style));
    }

    // Text.rich (not a bare RichText) so widget finders that match on Text
    // — including the app's own tests — still find this by its plain string.
    return Text.rich(TextSpan(children: spans, style: style));
  }
}
