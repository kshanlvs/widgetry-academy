import 'package:injectable/injectable.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:widgetry_academy/core/config/app_config.dart';
import 'package:widgetry_academy/core/utils/formatters.dart';
import 'package:widgetry_academy/features/payments/domain/payments.dart';

/// A one-page payment receipt (acknowledgement) the student can save or share.
/// Razorpay also emails its own receipt for every payment.
@LazySingleton(as: ReceiptBuilder)
class PdfReceiptBuilder implements ReceiptBuilder {
  static final _green = PdfColor.fromInt(0xFF0F6B56);
  static final _deep = PdfColor.fromInt(0xFF0C2A23);
  static final _muted = PdfColor.fromInt(0xFF5B6B63);
  static final _line = PdfColor.fromInt(0xFFE2E8E4);

  @override
  Future<List<int>> build(PaymentHistory h, Receipt r) async {
    pw.Font? regular, bold;
    try {
      regular = await PdfGoogleFonts.robotoRegular();
      bold = await PdfGoogleFonts.robotoBold();
    } catch (_) {
      // Offline: built-in fonts, rupee sign written as "Rs"
    }
    final unicode = regular != null;
    String money(int n) => unicode ? Fmt.rupees(n) : 'Rs ${Fmt.rupees(n).substring(1)}';
    pw.TextStyle st({double size = 10, bool b = false, PdfColor? color}) =>
        pw.TextStyle(font: b ? bold : regular, fontWeight: b ? pw.FontWeight.bold : pw.FontWeight.normal, fontSize: size, color: color ?? _deep);

    pw.Widget row(String k, String v, {bool strong = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Row(children: [
            pw.Expanded(child: pw.Text(k, style: st(color: _muted))),
            pw.Text(v, style: st(b: strong, size: strong ? 12 : 10)),
          ]),
        );

    final paid = r.paidAt ?? DateTime.now();
    final doc = pw.Document(title: 'Receipt ${r.paymentId}', author: AppConfig.businessName, creator: AppConfig.businessName);
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(48, 48, 48, 40),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Expanded(
            child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text(AppConfig.businessName, style: st(size: 18, b: true)),
              pw.SizedBox(height: 4),
              pw.Text('${AppConfig.businessOwner} · ${AppConfig.businessAddress}', style: st(size: 9, color: _muted)),
              pw.Text('${AppConfig.businessEmail} · ${AppConfig.siteUrl.replaceFirst('https://', '')}', style: st(size: 9, color: _muted)),
              pw.Text('Udyam: ${AppConfig.udyam}', style: st(size: 9, color: _muted)),
            ]),
          ),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('PAYMENT RECEIPT', style: st(size: 11, b: true, color: _green)),
            pw.SizedBox(height: 4),
            pw.Text(Fmt.date(paid), style: st(size: 9, color: _muted)),
          ]),
        ]),
        pw.SizedBox(height: 24),
        pw.Container(height: 1, color: _line),
        pw.SizedBox(height: 18),
        pw.Text('Received from', style: st(size: 9, color: _muted)),
        pw.SizedBox(height: 3),
        pw.Text(h.name ?? '', style: st(size: 12, b: true)),
        if ((h.email ?? '').isNotEmpty) pw.Text(h.email!, style: st(size: 10)),
        if ((h.phone ?? '').isNotEmpty) pw.Text(h.phone!, style: st(size: 10)),
        pw.SizedBox(height: 22),
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(children: [
            pw.Row(children: [
              pw.Expanded(child: pw.Text('${h.course}: ${r.title}', style: st(b: true, size: 11))),
              pw.Text(money(r.amount), style: st(b: true, size: 11)),
            ]),
            pw.SizedBox(height: 10),
            pw.Container(height: 1, color: _line),
            pw.SizedBox(height: 6),
            row('Payment ID', r.paymentId),
            row('Order ID', r.orderId),
            row('Paid by', '${r.methodLabel} via Razorpay'),
            row('Date', Fmt.date(paid)),
          ]),
        ),
        pw.SizedBox(height: 18),
        if (h.total != null) ...[
          row('Course fee', money(h.total!)),
          row('Paid so far', money(h.amountPaid)),
          row('Balance due', money(h.due ?? (h.total! - h.amountPaid).clamp(0, h.total!)), strong: true),
        ] else
          row('Amount paid', money(r.amount), strong: true),
        pw.Spacer(),
        pw.Container(height: 1, color: _line),
        pw.SizedBox(height: 8),
        pw.Text(
          'This is a payment acknowledgement from ${AppConfig.businessName}. Razorpay also emails a receipt for every payment. '
          'Refunds follow our refund policy at ${AppConfig.refundUrl.replaceFirst('https://', '')}. Questions: WhatsApp +${AppConfig.whatsappNumber}.',
          style: st(size: 8.5, color: _muted),
        ),
      ]),
    ));
    return doc.save();
  }
}
