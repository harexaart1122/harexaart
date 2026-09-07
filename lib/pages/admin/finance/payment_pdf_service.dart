
// ============================================================================
// HAREXAART - PAYMENT PDF SERVICE
// ============================================================================
//
// Service PDF untuk Finance.
//
// ALUR:
//
// INPUT ORDER
//      ↓
// ORDER STORE
//      ↓
// KEEPER SELESAI
//      ↓
// PAYMENT RECORD
//      ↓
// PAYMENT PDF SERVICE
//      ↓
// PDF
//
// ATURAN:
// - Workspace harus sesuai.
// - Nominal berasal dari PaymentRecord.amount.
// - Tidak ada input nominal manual.
// - Foto produk dibawa dari OrderStore.
// - Timestamp tidak boleh diubah.
// - PDF dapat di-preview, print, dan share.
// ============================================================================

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../../data/order_store.dart';
import 'payment_model.dart';

// ============================================================================
// PAYMENT PDF SERVICE
// ============================================================================

class PaymentPdfService {
  const PaymentPdfService();

  // ==========================================================================
  // FORMAT RUPIAH
  // ==========================================================================

  String formatRupiah(int value) {
    final String digits = value.toString();

    if (digits.isEmpty) {
      return 'Rp 0';
    }

    final StringBuffer result = StringBuffer();

    for (int i = 0; i < digits.length; i++) {
      final int positionFromEnd = digits.length - i;

      result.write(digits[i]);

      if (positionFromEnd > 1 &&
          positionFromEnd % 3 == 1) {
        result.write('.');
      }
    }

    return 'Rp ${result.toString()}';
  }

  // ==========================================================================
  // FORMAT TANGGAL
  // ==========================================================================

  String formatDateTime(DateTime? date) {
    if (date == null) {
      return '-';
    }

    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    final String year = date.year.toString();

    final String hour = date.hour.toString().padLeft(2, '0');
    final String minute = date.minute.toString().padLeft(2, '0');

    return '$day/$month/$year • $hour:$minute';
  }

  // ==========================================================================
  // FILTER DATA WORKSPACE
  // ==========================================================================

  List<PaymentRecord> getWorkspaceRecords({
    required List<PaymentRecord> records,
    required String workspaceId,
  }) {
    return records
        .where(
          (PaymentRecord record) =>
      record.workspaceId == workspaceId,
    )
        .toList();
  }

  // ==========================================================================
  // FILTER ORDER YANG LAYAK DIBAYAR
  // ==========================================================================

  List<PaymentRecord> getEligibleRecords({
    required List<PaymentRecord> records,
    required String workspaceId,
  }) {
    return records.where(
          (PaymentRecord record) {
        if (record.workspaceId != workspaceId) {
          return false;
        }

        if (!record.isEligibleForPayment) {
          return false;
        }

        if (!record.isValidForPayment(workspaceId)) {
          return false;
        }

        return true;
      },
    ).toList();
  }

  // ==========================================================================
  // TOTAL NOMINAL
  // ==========================================================================

  int calculateTotal({
    required List<PaymentRecord> records,
    required String workspaceId,
  }) {
    int total = 0;

    for (final PaymentRecord record in records) {
      if (record.workspaceId != workspaceId) {
        continue;
      }

      total += record.amount;
    }

    return total;
  }

  // ==========================================================================
  // DATA REPORT
  // ==========================================================================

  List<Map<String, dynamic>> preparePaymentReport({
    required List<PaymentRecord> records,
    required String workspaceId,
  }) {
    final List<Map<String, dynamic>> report =
    <Map<String, dynamic>>[];

    for (final PaymentRecord record in records) {
      if (record.workspaceId != workspaceId) {
        continue;
      }

      report.add(
        <String, dynamic>{
          'payment_id': record.paymentId,
          'order_id': record.orderId,
          'workspace_id': record.workspaceId,
          'workspace_name': record.workspaceName,
          'product_name': record.productName,
          'ukuran': record.ukuran,
          'frame': record.frame,
          'amount': record.amount,
          'order_created_at': record.orderCreatedAt,
          'completed_at': record.completedAt,
          'paid_at': record.paidAt,
          'payment_status': record.paymentStatus.name,
          'product_image': record.productImage,
          'product_image_url': record.productImageUrl,
          'product_image_file_name':
          record.productImageFileName,
        },
      );
    }

    return report;
  }

  // ==========================================================================
  // RINGKASAN
  // ==========================================================================

  Map<String, dynamic> buildReportSummary({
    required List<PaymentRecord> records,
    required String workspaceId,
    required String workspaceName,
  }) {
    final List<PaymentRecord> workspaceRecords =
    getWorkspaceRecords(
      records: records,
      workspaceId: workspaceId,
    );

    final int total = calculateTotal(
      records: workspaceRecords,
      workspaceId: workspaceId,
    );

    final int paidCount = workspaceRecords
        .where(
          (PaymentRecord record) =>
      record.paymentStatus ==
          PaymentStatus.sudahDibayar,
    )
        .length;

    final int unpaidCount = workspaceRecords
        .where(
          (PaymentRecord record) =>
      record.paymentStatus ==
          PaymentStatus.belumDibayar,
    )
        .length;

    return <String, dynamic>{
      'workspace_id': workspaceId,
      'workspace_name': workspaceName,
      'total_records': workspaceRecords.length,
      'paid_count': paidCount,
      'unpaid_count': unpaidCount,
      'total_amount': total,
      'total_amount_formatted': formatRupiah(total),
    };
  }

  // ==========================================================================
  // VALIDASI
  // ==========================================================================

  bool validateRecords({
    required List<PaymentRecord> records,
    required String workspaceId,
  }) {
    if (workspaceId.trim().isEmpty) {
      return false;
    }

    if (records.isEmpty) {
      return false;
    }

    for (final PaymentRecord record in records) {
      if (record.workspaceId != workspaceId) {
        return false;
      }

      if (record.orderId.trim().isEmpty) {
        return false;
      }

      if (record.amount <= 0) {
        return false;
      }
    }

    return true;
  }

  // ==========================================================================
  // NAMA FILE
  // ==========================================================================

  String buildFileName({
    required String workspaceId,
    DateTime? date,
  }) {
    final DateTime targetDate =
        date ?? DateTime.now();

    final String year =
    targetDate.year.toString();

    final String month =
    targetDate.month
        .toString()
        .padLeft(2, '0');

    final String day =
    targetDate.day
        .toString()
        .padLeft(2, '0');

    final String safeWorkspace =
    workspaceId.trim().isEmpty
        ? 'workspace'
        : workspaceId.trim();

    return 'payment_report_${safeWorkspace}_'
        '$year$month$day.pdf';
  }

  // ==========================================================================
  // DATA PDF
  // ==========================================================================

  Map<String, dynamic> preparePdfData({
    required List<PaymentRecord> records,
    required String workspaceId,
    required String workspaceName,
  }) {
    final List<PaymentRecord> workspaceRecords =
    getWorkspaceRecords(
      records: records,
      workspaceId: workspaceId,
    );

    final int total = calculateTotal(
      records: workspaceRecords,
      workspaceId: workspaceId,
    );

    return <String, dynamic>{
      'file_name': buildFileName(
        workspaceId: workspaceId,
      ),
      'workspace_id': workspaceId,
      'workspace_name': workspaceName,
      'records': preparePaymentReport(
        records: workspaceRecords,
        workspaceId: workspaceId,
      ),
      'total': total,
      'total_formatted': formatRupiah(total),
      'generated_at': DateTime.now(),
    };
  }

  // ==========================================================================
  // GENERATE PDF
  // ==========================================================================

  Future<Uint8List> generatePaymentPdf({
    required List<PaymentRecord> records,
    required String workspaceId,
    required String workspaceName,
  }) async {
    final List<PaymentRecord> workspaceRecords =
    getWorkspaceRecords(
      records: records,
      workspaceId: workspaceId,
    );

    if (workspaceRecords.isEmpty) {
      throw Exception(
        'Tidak ada data pembayaran untuk workspace ini.',
      );
    }

    if (!validateRecords(
      records: workspaceRecords,
      workspaceId: workspaceId,
    )) {
      throw Exception(
        'Data pembayaran tidak valid.',
      );
    }

    final pw.Document document =
    pw.Document();

    final int total = calculateTotal(
      records: workspaceRecords,
      workspaceId: workspaceId,
    );

    final DateTime generatedAt =
    DateTime.now();

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(
          28,
          28,
          28,
          32,
        ),
        header: (pw.Context context) {
          return _buildPdfHeader(
            workspaceName: workspaceName,
            generatedAt: generatedAt,
          );
        },
        footer: (pw.Context context) {
          return _buildPdfFooter(context);
        },
        build: (pw.Context context) {
          final List<pw.Widget> widgets =
          <pw.Widget>[];

          widgets.add(
            _buildReportTitle(
              workspaceName: workspaceName,
            ),
          );

          widgets.add(
            pw.SizedBox(height: 16),
          );

          widgets.add(
            _buildSummaryCard(
              recordCount:
              workspaceRecords.length,
              total: total,
            ),
          );

          widgets.add(
            pw.SizedBox(height: 18),
          );

          for (
          int index = 0;
          index < workspaceRecords.length;
          index++
          ) {
            final PaymentRecord record =
            workspaceRecords[index];

            widgets.add(
              _buildPaymentCard(
                record: record,
                number: index + 1,
              ),
            );

            if (
            index !=
                workspaceRecords.length - 1
            ) {
              widgets.add(
                pw.SizedBox(height: 12),
              );
            }
          }

          widgets.add(
            pw.SizedBox(height: 18),
          );

          widgets.add(
            _buildGrandTotal(
              total: total,
            ),
          );

          return widgets;
        },
      ),
    );

    return document.save();
  }

  // ==========================================================================
  // HEADER
  // ==========================================================================

  pw.Widget _buildPdfHeader({
    required String workspaceName,
    required DateTime generatedAt,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(
        bottom: 10,
      ),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(
            width: 1,
            color: PdfColors.grey400,
          ),
        ),
      ),
      child: pw.Row(
        crossAxisAlignment:
        pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment:
              pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'HAREXAART',
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight:
                    pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 3),
                pw.Text(
                  'Laporan Pembayaran',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey700,
                  ),
                ),
              ],
            ),
          ),
          pw.Column(
            crossAxisAlignment:
            pw.CrossAxisAlignment.end,
            children: <pw.Widget>[
              pw.Text(
                workspaceName,
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight:
                  pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 3),
              pw.Text(
                formatDateTime(generatedAt),
                style: pw.TextStyle(
                  fontSize: 7.5,
                  color: PdfColors.grey700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // JUDUL
  // ==========================================================================

  pw.Widget _buildReportTitle({
    required String workspaceName,
  }) {
    return pw.Column(
      crossAxisAlignment:
      pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          'PAYMENT REPORT',
          style: pw.TextStyle(
            fontSize: 20,
            fontWeight:
            pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          workspaceName,
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey700,
          ),
        ),
        pw.SizedBox(height: 3),
        pw.Text(
          'Dokumen resmi finalisasi pembayaran order.',
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey600,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // SUMMARY
  // ==========================================================================

  pw.Widget _buildSummaryCard({
    required int recordCount,
    required int total,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(14),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius:
        pw.BorderRadius.circular(8),
        border: pw.Border.all(
          color: PdfColors.grey300,
        ),
      ),
      child: pw.Row(
        children: <pw.Widget>[
          pw.Expanded(
            child: _buildSummaryItem(
              label: 'TOTAL ORDER',
              value: recordCount.toString(),
            ),
          ),
          pw.SizedBox(width: 15),
          pw.Expanded(
            child: _buildSummaryItem(
              label: 'TOTAL PEMBAYARAN',
              value: formatRupiah(total),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // SUMMARY ITEM
  // ==========================================================================

  pw.Widget _buildSummaryItem({
    required String label,
    required String value,
  }) {
    return pw.Column(
      crossAxisAlignment:
      pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7,
            color: PdfColors.grey600,
            fontWeight:
            pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 14,
            fontWeight:
            pw.FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // PAYMENT CARD
  // ==========================================================================

  pw.Widget _buildPaymentCard({
    required PaymentRecord record,
    required int number,
  }) {
    pw.MemoryImage? productImage;

    final Uint8List? imageBytes =
        record.productImage;

    if (
    imageBytes != null &&
        imageBytes.isNotEmpty
    ) {
      productImage =
          pw.MemoryImage(imageBytes);
    }

    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.grey300,
          width: 0.8,
        ),
        borderRadius:
        pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        crossAxisAlignment:
        pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          _buildProductImage(
            productImage,
          ),
          pw.SizedBox(width: 12),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment:
              pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Row(
                  crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Expanded(
                      child: pw.Text(
                        '${number.toString().padLeft(2, '0')}  ${record.orderId}',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight:
                          pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    _buildPaymentStatusBadge(
                      record,
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                _buildDetailRow(
                  'Produk',
                  record.productName,
                ),
                _buildDetailRow(
                  'Ukuran',
                  record.ukuran,
                ),
                _buildDetailRow(
                  'Frame',
                  record.frame,
                ),
                _buildDetailRow(
                  'Workspace',
                  record.workspaceName,
                ),
                pw.SizedBox(height: 7),
                pw.Container(
                  height: 0.5,
                  color: PdfColors.grey300,
                ),
                pw.SizedBox(height: 7),
                _buildDetailRow(
                  'Input Order',
                  formatDateTime(
                    record.orderCreatedAt,
                  ),
                ),
                _buildDetailRow(
                  'Keeper Selesai',
                  formatDateTime(
                    record.completedAt,
                  ),
                ),
                _buildDetailRow(
                  'Admin Bayar',
                  formatDateTime(
                    record.paidAt,
                  ),
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  children: <pw.Widget>[
                    pw.Expanded(
                      child: pw.Text(
                        'NOMINAL PEMBAYARAN',
                        style: pw.TextStyle(
                          fontSize: 7,
                          color:
                          PdfColors.grey600,
                          fontWeight:
                          pw.FontWeight.bold,
                        ),
                      ),
                    ),
                    pw.Text(
                      formatRupiah(record.amount),
                      style: pw.TextStyle(
                        fontSize: 13,
                        fontWeight:
                        pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FOTO PRODUK
  // ==========================================================================

  pw.Widget _buildProductImage(
      pw.MemoryImage? image,
      ) {
    if (image == null) {
      return pw.Container(
        width: 82,
        height: 82,
        decoration: pw.BoxDecoration(
          color: PdfColors.grey100,
          borderRadius:
          pw.BorderRadius.circular(6),
          border: pw.Border.all(
            color: PdfColors.grey300,
          ),
        ),
        child: pw.Center(
          child: pw.Column(
            mainAxisAlignment:
            pw.MainAxisAlignment.center,
            children: <pw.Widget>[
              pw.Text(
                'NO',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight:
                  pw.FontWeight.bold,
                  color:
                  PdfColors.grey600,
                ),
              ),
              pw.Text(
                'IMAGE',
                style: pw.TextStyle(
                  fontSize: 7,
                  color:
                  PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return pw.Container(
      width: 82,
      height: 82,
      decoration: pw.BoxDecoration(
        borderRadius:
        pw.BorderRadius.circular(6),
        border: pw.Border.all(
          color: PdfColors.grey300,
        ),
      ),
      child: pw.ClipRRect(
        horizontalRadius: 6,
        verticalRadius: 6,
        child: pw.Image(
          image,
          width: 82,
          height: 82,
          fit: pw.BoxFit.cover,
        ),
      ),
    );
  }

  // ==========================================================================
  // STATUS
  // ==========================================================================

  pw.Widget _buildPaymentStatusBadge(
      PaymentRecord record,
      ) {
    final bool paid =
        record.paymentStatus ==
            PaymentStatus.sudahDibayar;

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(
        horizontal: 7,
        vertical: 4,
      ),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey200,
        borderRadius:
        pw.BorderRadius.circular(5),
      ),
      child: pw.Text(
        paid
            ? 'SUDAH DIBAYAR'
            : 'BELUM DIBAYAR',
        style: pw.TextStyle(
          fontSize: 6.5,
          fontWeight:
          pw.FontWeight.bold,
          color: PdfColors.grey800,
        ),
      ),
    );
  }

  // ==========================================================================
  // DETAIL ROW
  // ==========================================================================

  pw.Widget _buildDetailRow(
      String label,
      String value,
      ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(
        bottom: 3,
      ),
      child: pw.Row(
        crossAxisAlignment:
        pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.SizedBox(
            width: 75,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 7.5,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 7.5,
                fontWeight:
                pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // TOTAL
  // ==========================================================================

  pw.Widget _buildGrandTotal({
    required int total,
  }) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(
          color: PdfColors.grey500,
          width: 1,
        ),
        borderRadius:
        pw.BorderRadius.circular(8),
      ),
      child: pw.Row(
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment:
              pw.CrossAxisAlignment.start,
              children: <pw.Widget>[
                pw.Text(
                  'TOTAL PEMBAYARAN',
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.grey600,
                    fontWeight:
                    pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 5),
                pw.Text(
                  'Finalisasi pembayaran seluruh order dalam laporan.',
                  style: pw.TextStyle(
                    fontSize: 7,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 15),
          pw.Text(
            formatRupiah(total),
            style: pw.TextStyle(
              fontSize: 16,
              fontWeight:
              pw.FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // FOOTER
  // ==========================================================================

  pw.Widget _buildPdfFooter(
      pw.Context context,
      ) {
    return pw.Container(
      padding: const pw.EdgeInsets.only(
        top: 8,
      ),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(
            width: 0.6,
            color: PdfColors.grey300,
          ),
        ),
      ),
      child: pw.Row(
        children: <pw.Widget>[
          pw.Expanded(
            child: pw.Text(
              'HarexaArt • Finance Payment Report',
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.grey600,
              ),
            ),
          ),
          pw.Text(
            'Halaman ${context.pageNumber} / ${context.pagesCount}',
            style: pw.TextStyle(
              fontSize: 7,
              color: PdfColors.grey600,
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PREVIEW PDF
  // ==========================================================================

  Widget buildPdfPreview({
    required List<PaymentRecord> records,
    required String workspaceId,
    required String workspaceName,
  }) {
    return PdfPreview(
      build: (PdfPageFormat format) async {
        return generatePaymentPdf(
          records: records,
          workspaceId: workspaceId,
          workspaceName: workspaceName,
        );
      },
      canChangePageFormat: false,
      canChangeOrientation: false,
      allowPrinting: true,
      allowSharing: true,
      pdfFileName: buildFileName(
        workspaceId: workspaceId,
      ),
    );
  }

  // ==========================================================================
  // PRINT / SHARE PDF
  // ==========================================================================

  Future<void> printOrSharePaymentPdf({
    required List<PaymentRecord> records,
    required String workspaceId,
    required String workspaceName,
  }) async {
    final Uint8List pdfBytes =
    await generatePaymentPdf(
      records: records,
      workspaceId: workspaceId,
      workspaceName: workspaceName,
    );

    final String fileName =
    buildFileName(
      workspaceId: workspaceId,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: fileName,
    );
  }
}
