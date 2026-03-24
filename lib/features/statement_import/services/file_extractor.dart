import 'dart:io';
import 'package:csv/csv.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class FileExtractor {
  static Future<List<List<dynamic>>> extractCsvContent(String filePath) async {
    final file = File(filePath);
    final content = await file.readAsString();
    return Csv().decode(content);
  }

  static Future<String> extractPdfText(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final text = PdfTextExtractor(document).extractText();
    print("Extracted PDF Text: $text");
    document.dispose();
    return text;
  }
}
