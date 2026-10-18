import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/features/profile/domain/entities/candidate.dart';
import 'package:widgetry_academy/features/profile/domain/repositories/profile_repository.dart';

/// ATS-friendly resume, same structure as the website's resume builder:
/// one column, real text, standard section names, consistent dates.
@LazySingleton(as: ResumeBuilder)
class PdfResumeBuilder implements ResumeBuilder {
  static final _accents = <String, PdfColor>{
    'green': const PdfColor.fromInt(0xFF0F6B56),
    'navy': const PdfColor.fromInt(0xFF1D3557),
    'black': const PdfColor.fromInt(0xFF111111),
    'maroon': const PdfColor.fromInt(0xFF7A1F2B),
    'teal': const PdfColor.fromInt(0xFF0E6D7A),
    'purple': const PdfColor.fromInt(0xFF53389E),
  };

  static const _groups = <String, List<String>>{
    'Languages & Frameworks': ['Flutter', 'Dart', 'Kotlin', 'Swift', 'Java', 'Objective-C', 'JavaScript', 'TypeScript', 'Flutter Web', 'Flame'],
    'UI': ['Jetpack Compose', 'SwiftUI', 'UIKit', 'Material Design', 'Animations'],
    'State & Concurrency': ['Bloc', 'Provider', 'Riverpod', 'GetX', 'MobX', 'Redux', 'Coroutines', 'Flow', 'Combine'],
    'Data & Integrations': ['Firebase', 'REST APIs', 'GraphQL', 'Retrofit', 'Room', 'Core Data', 'SQLite', 'Hive', 'Google Maps', 'Push Notifications'],
    'Architecture & Practices': ['Clean Architecture', 'MVVM', 'Dependency Injection', 'Hilt', 'Testing', 'Espresso', 'XCTest', 'CI/CD', 'Gradle', 'Xcode', 'Git'],
  };

  @override
  Future<Uint8List> build(Candidate p, ResumeSettings s) async {
    final fonts = await _fonts(s.template);
    final accent = s.template == 'classic' ? PdfColors.black : (_accents[s.accent] ?? _accents['green']!);
    final compact = s.template == 'compact';
    final base = compact ? 9.6 : 10.4;
    final txt = fonts == null ? _ascii : (String v) => v;
    final doc = pw.Document(title: '${p.fullName} - Resume', author: p.fullName, creator: 'Widgetry Academy');

    pw.TextStyle st({double? size, bool bold = false, PdfColor? color, bool italic = false}) => pw.TextStyle(
          font: fonts == null ? null : (bold ? fonts.$2 : (italic ? fonts.$3 : fonts.$1)),
          fontSize: size ?? base,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
          color: color ?? PdfColors.grey900,
          lineSpacing: 1.6,
        );

    pw.Widget heading(String title) => pw.Container(
          margin: pw.EdgeInsets.only(top: compact ? 7 : 10, bottom: 4),
          padding: const pw.EdgeInsets.only(bottom: 2),
          decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: s.template == 'modern' ? PdfColors.white : accent, width: 0.7))),
          child: pw.Text(title.toUpperCase(), style: st(size: base, bold: true, color: accent)),
        );

    pw.Widget row(String left, String right, {String? sub}) => pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.RichText(text: pw.TextSpan(children: [
              pw.TextSpan(text: txt(left), style: st(bold: true)),
              if (sub != null && sub.isNotEmpty) pw.TextSpan(text: txt(' | $sub'), style: st(color: PdfColors.grey700)),
            ])),
          ),
          if (right.isNotEmpty) pw.Text(txt(right), style: st(size: base - 1, color: PdfColors.grey700)),
        ]);

    pw.Widget bullets(List<String> items) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          for (final b in items)
            pw.Bullet(text: txt(b), style: st(), bulletSize: 2.6, bulletMargin: const pw.EdgeInsets.only(top: 4.5, right: 6), padding: const pw.EdgeInsets.only(top: 1.5)),
        ]);

    final contact = [
      if (s.shows('city') && (p.city ?? '').isNotEmpty) '${p.city}, India',
      if (s.shows('phone') && (p.phone ?? '').isNotEmpty) _phone(p.phone!),
      if (s.shows('email') && p.email.isNotEmpty) p.email,
      for (final u in [p.linkedinUrl, p.githubUrl, p.portfolioUrl]) if ((u ?? '').startsWith('http')) Fmt.shortUrl(u!),
    ].join('  |  ');

    final summary = (p.about ?? '').trim().isNotEmpty ? p.about!.trim() : _autoSummary(p);
    final certs = [
      if (p.verification == 'verified') const CertItem(name: 'Widgetry Verified Flutter Developer (technical interview)', issuer: 'Widgetry Academy'),
      ...p.certifications,
    ];
    final photo = s.showPhoto && s.shows('photo') && (p.photo ?? '').startsWith('data:image/') ? pw.MemoryImage(UriData.parse(p.photo!).contentAsBytes()) : null;
    final title = (s.title ?? '').trim().isNotEmpty ? s.title!.trim() : p.headline;
    final centered = s.template == 'classic' && photo == null;

    final header = pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 8),
      decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: accent, width: s.template == 'modern' ? 2 : 1.2))),
      child: pw.Row(children: [
        if (photo != null) ...[pw.ClipOval(child: pw.Image(photo, width: 58, height: 58, fit: pw.BoxFit.cover)), pw.SizedBox(width: 14)],
        pw.Expanded(
          child: pw.Column(crossAxisAlignment: centered ? pw.CrossAxisAlignment.center : pw.CrossAxisAlignment.start, children: [
            pw.Text(txt(s.template == 'classic' ? p.fullName.toUpperCase() : p.fullName), style: st(size: compact ? 19 : 23, bold: true, color: PdfColors.grey900)),
            pw.SizedBox(height: 3),
            pw.Text(txt(title), style: st(size: base + 1.2, bold: s.template != 'classic', italic: s.template == 'classic', color: s.template == 'classic' ? PdfColors.grey800 : accent)),
            pw.SizedBox(height: 4),
            pw.Text(txt(contact), style: st(size: base - 1, color: PdfColors.grey700), textAlign: centered ? pw.TextAlign.center : pw.TextAlign.left),
          ]),
        ),
      ]),
    );

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4.copyWith(marginLeft: 40, marginRight: 40, marginTop: 34, marginBottom: 34),
      build: (_) => [
        header,
        if (s.shows('summary')) ...[heading('Professional Summary'), pw.Text(txt(summary), style: st())],
        if (p.skills.isNotEmpty) ...[
          heading('Technical Skills'),
          for (final g in _group(p.skills)) pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 1.5),
            child: pw.RichText(text: pw.TextSpan(children: [pw.TextSpan(text: '${g.$1}: ', style: st(bold: true)), pw.TextSpan(text: txt(g.$2.join(', ')), style: st())])),
          ),
        ],
        if (p.experience.isNotEmpty || (p.currentCompany ?? '').isNotEmpty) ...[
          heading('Professional Experience'),
          if (p.experience.isEmpty) row(p.headline, 'Present', sub: p.currentCompany),
          for (final w in p.experience)
            pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              row(w.role, '${Fmt.yearMonth(w.start)} – ${Fmt.yearMonth(w.end)}', sub: w.company),
              if (w.bullets.isNotEmpty) bullets(w.bullets),
            ])),
        ],
        if (s.shows('projects') && p.apps.isNotEmpty) ...[
          heading('Projects'),
          for (final a in p.apps)
            pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              row(a.name, (a.url ?? '').startsWith('http') ? Fmt.shortUrl(a.url!) : '', sub: a.role),
              if ((a.about ?? '').isNotEmpty) bullets([a.about!]),
            ])),
        ],
        if (s.shows('education') && p.education.isNotEmpty) ...[
          heading('Education'),
          for (final e in p.education) pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: row(e.degree, e.year?.toString() ?? '', sub: [e.institute, if ((e.score ?? '').isNotEmpty) e.score!].join(' | '))),
        ],
        if (s.shows('certifications') && certs.isNotEmpty) ...[
          heading('Certifications'),
          bullets([for (final c in certs) [c.name, if ((c.issuer ?? '').isNotEmpty) '– ${c.issuer}', if (c.year != null) '(${c.year})'].join(' ')]),
        ],
      ],
    ));
    return doc.save();
  }

  /// Unicode fonts (₹, –, ★) from Google Fonts. Cached by the printing package after the first download.
  /// Returns null when offline; the PDF then uses built-in fonts with plain-ASCII text.
  Future<(pw.Font, pw.Font, pw.Font)?> _fonts(String template) async {
    try {
      if (template == 'classic') {
        return (await PdfGoogleFonts.notoSerifRegular(), await PdfGoogleFonts.notoSerifBold(), await PdfGoogleFonts.notoSerifItalic());
      }
      return (await PdfGoogleFonts.robotoRegular(), await PdfGoogleFonts.robotoBold(), await PdfGoogleFonts.robotoItalic());
    } catch (_) {
      return null;
    }
  }

  static String _ascii(String v) => v
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('·', '|')
      .replaceAll('★', '*')
      .replaceAll('✓', '')
      .replaceAll('₹', 'Rs ')
      .replaceAll('’', "'")
      .replaceAll(RegExp(r'[^\x00-\xFF]'), '');

  static String _phone(String v) {
    final d = v.replaceAll(RegExp(r'\D'), '');
    if (RegExp(r'^91\d{10}$').hasMatch(d)) return '+91 ${d.substring(2, 7)} ${d.substring(7)}';
    if (RegExp(r'^\d{10}$').hasMatch(d)) return '+91 ${d.substring(0, 5)} ${d.substring(5)}';
    return v;
  }

  static List<(String, List<String>)> _group(List<String> skills) {
    final left = [...skills];
    final out = <(String, List<String>)>[];
    _groups.forEach((label, list) {
      final got = list.where((s) => left.any((x) => x.toLowerCase() == s.toLowerCase())).toList();
      if (got.isNotEmpty) {
        out.add((label, got));
        left.removeWhere((x) => got.any((g) => g.toLowerCase() == x.toLowerCase()));
      }
    });
    if (left.isNotEmpty) out.add((out.isEmpty ? 'Skills' : 'Other', left));
    return out;
  }

  static String _autoSummary(Candidate p) {
    const roles = {'flutter': ('Flutter developer', 'cross-platform Android and iOS apps'), 'android': ('Android developer', 'native Android apps'), 'ios': ('iOS developer', 'native iOS apps'), 'react-native': ('React Native developer', 'cross-platform Android and iOS apps')};
    final cats = p.categories.where(roles.containsKey).toList();
    final (role, what) = cats.length == 1 ? roles[cats.first]! : cats.length > 1 ? ('Mobile developer', 'apps with ${cats.map((c) => roles[c]!.$1.split(' ').first).join(' and ')}') : roles['flutter']!;
    final yrs = p.experienceYears;
    final yrsText = yrs >= 1 ? ' with ${yrs == yrs.roundToDouble() ? yrs.toInt() : yrs} year${yrs == 1 ? '' : 's'} of experience' : '';
    final names = p.apps.map((a) => a.name).where((n) => n.isNotEmpty).take(2).toList();
    final top = p.skills.where((s) => !RegExp(r'^(flutter|dart|kotlin|swift)$', caseSensitive: false).hasMatch(s)).take(4).toList();
    final stack = top.isEmpty ? '' : ' Skilled in ${top.length == 1 ? top.first : '${top.sublist(0, top.length - 1).join(', ')} and ${top.last}'}.';
    return '${role[0].toUpperCase()}${role.substring(1)}$yrsText building $what${names.isEmpty ? '' : ', including ${names.join(' and ')}'}.$stack Focused on clean, maintainable code and smooth user experiences.';
  }
}
