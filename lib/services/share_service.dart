import 'dart:io';

import 'package:share_plus/share_plus.dart';

class ShareService {
  Future<void> shareFiles(List<File> files, {required String subject}) async {
    if (files.isEmpty) return;
    await Share.shareXFiles(
      files.map((f) => XFile(f.path)).toList(),
      subject: subject,
    );
  }
}
