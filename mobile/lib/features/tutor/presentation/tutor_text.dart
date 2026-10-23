import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:widgetry_academy/core/theme/app_colors.dart';
import 'package:widgetry_academy/core/widgets/common.dart';

/// Renders the small amount of Markdown the tutor writes: ``` code blocks (with a copy button),
/// **bold**, `inline code`, bullet and numbered lists, and # headings. Anything else shows as plain text.
class TutorText extends StatelessWidget {
  const TutorText(this.text, {super.key});
  final String text;

  /// Splits [text] into prose and fenced code blocks, in order. Exposed for tests.
  static List<({bool code, String lang, String body})> blocks(String text) {
    final out = <({bool code, String lang, String body})>[];
    final fence = RegExp(r'```([\w+-]*)[^\n]*\n([\s\S]*?)(?:```|$)');
    var at = 0;
    for (final m in fence.allMatches(text)) {
      final before = text.substring(at, m.start).trim();
      if (before.isNotEmpty) out.add((code: false, lang: '', body: before));
      out.add((code: true, lang: m.group(1) ?? '', body: (m.group(2) ?? '').replaceAll(RegExp(r'\s+$'), '')));
      at = m.end;
    }
    final rest = text.substring(at).trim();
    if (rest.isNotEmpty) out.add((code: false, lang: '', body: rest));
    return out;
  }

  /// **bold** and `code` inside one line.
  static List<InlineSpan> inline(String line, TextStyle base, Color codeBg) {
    final spans = <InlineSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*|`([^`]+)`');
    var at = 0;
    for (final m in re.allMatches(line)) {
      if (m.start > at) spans.add(TextSpan(text: line.substring(at, m.start)));
      if (m.group(1) != null) {
        spans.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w700)));
      } else {
        spans.add(TextSpan(text: m.group(2), style: GoogleFonts.jetBrainsMono(fontSize: (base.fontSize ?? 14) * 0.9, backgroundColor: codeBg)));
      }
      at = m.end;
    }
    if (at < line.length) spans.add(TextSpan(text: line.substring(at)));
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final p = Palette.of(context);
    final base = t.bodyMedium!.copyWith(color: p.ink, height: 1.5);
    final children = <Widget>[];
    for (final b in blocks(text)) {
      if (children.isNotEmpty) children.add(const SizedBox(height: Space.sm));
      children.add(b.code ? _CodeBlock(code: b.body, lang: b.lang) : _prose(b.body, base, p));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }

  Widget _prose(String body, TextStyle base, Palette p) {
    final lines = <Widget>[];
    for (final raw in body.split('\n')) {
      final line = raw.trimRight();
      if (line.trim().isEmpty) {
        lines.add(const SizedBox(height: 6));
        continue;
      }
      final bullet = RegExp(r'^\s*[-*•]\s+(.*)$').firstMatch(line);
      final number = RegExp(r'^\s*(\d+)[.)]\s+(.*)$').firstMatch(line);
      final heading = RegExp(r'^#{1,4}\s+(.*)$').firstMatch(line);
      if (heading != null) {
        lines.add(Text.rich(TextSpan(style: base.copyWith(fontWeight: FontWeight.w700), children: inline(heading.group(1)!, base, p.line))));
      } else if (bullet != null || number != null) {
        lines.add(Padding(
          padding: const EdgeInsets.only(left: 2, top: 1, bottom: 1),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(width: 20, child: Text(bullet != null ? '•' : '${number!.group(1)}.', style: base)),
            Expanded(child: Text.rich(TextSpan(style: base, children: inline(bullet?.group(1) ?? number!.group(2)!, base, p.line)))),
          ]),
        ));
      } else {
        lines.add(Text.rich(TextSpan(style: base, children: inline(line, base, p.line))));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: lines);
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code, required this.lang});
  final String code;
  final String lang;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(color: AppColors.deep, borderRadius: BorderRadius.circular(Radii.md)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 0),
          child: Row(children: [
            Text(lang.isEmpty ? 'code' : lang, style: GoogleFonts.jetBrainsMono(fontSize: 11.5, color: Colors.white54)),
            const Spacer(),
            IconButton(
              tooltip: 'Copy code',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.copy_rounded, size: 16, color: Colors.white70),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: code));
                showMessage(context, 'Code copied');
              },
            ),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          child: SelectableText(code, style: GoogleFonts.jetBrainsMono(fontSize: 12.5, color: const Color(0xFFE6F2EC), height: 1.45)),
        ),
      ]),
    );
  }
}
