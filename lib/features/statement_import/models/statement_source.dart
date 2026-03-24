import 'package:flutter/material.dart';

enum StatementSource {
  phonePe('PhonePe', 'assets/images/phonepe_logo.png', Colors.purple),
  gPay('Google Pay', 'assets/images/gpay_logo.png', Colors.blue);
  // hdfcBank('HDFC Bank', 'assets/images/hdfc_logo.png', Colors.blue),
  // sbi('SBI', 'assets/images/sbi_logo.png', Colors.blue);

  final String displayName;
  final String iconPath; // Will use Icon for now if image not present
  final Color brandColor;

  const StatementSource(this.displayName, this.iconPath, this.brandColor);
}
