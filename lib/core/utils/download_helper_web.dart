// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

/// Web implementation for downloading the release APK
void triggerApkDownload() {
  final anchor = html.AnchorElement(href: 'benaa-release.apk')
    ..setAttribute('download', 'benaa-release.apk')
    ..style.display = 'none';
  html.document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
}
