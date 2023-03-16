import 'package:dio/dio.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/dom.dart';
import 'package:revanced_manager/scraper/apk_downloader_interface.dart';
import 'package:revanced_manager/scraper/apk_info.dart';

class ApkMirrorDownloader implements IApkDownloader {
  final Dio _dio = Dio();
  final baseURL = 'https://www.apkmirror.com';

  @override
  Future<ApkInfo> getApkInfo(
      String packageName, Map<String, String>? params) async {
    final result = await _dio
        .get('$baseURL/?post_type=app_release&searchtype=apk&s=$packageName');
    final dom.Document html = dom.Document.html(result.data);

    final List<Element> listWidget = html.querySelectorAll(
      'div.listWidget',
    );

    final List<Element> appRow = listWidget.first.querySelectorAll(
      'div.appRow',
    );

    final title = appRow.first.querySelector('h5.appRowTitle');
    final version = title!.text.trim().split(' ').last;
    final link = title.querySelector('a')!.attributes['href'];
    final downlodPageURL = link!.replaceAll('release', 'android-apk-download');

    final friendlyTitle = title.text.split(' ');

    // combine friendlyTitle except last string (to exclude version)
    final friendlyTitleString =
        friendlyTitle.sublist(0, friendlyTitle.length - 2).join(' ');

    return ApkInfo(
      name: friendlyTitleString,
      version: version,
      size: '',
      downloadUrl: '$baseURL$downlodPageURL',
    );
  }

  Future<Map<String, String>> getApkDownloadUrl(String url) async {
    final result = await Dio().get(url);
    final dom.Document html = dom.Document.html(result.data);

    final String size =
        html.querySelectorAll('div.appspec-row > div.appspec-value')[1].text;

    final String downloadUrl =
        baseURL + html.querySelector('a.downloadButton')!.attributes['href']!;

    return {
      'downloadUrl': downloadUrl,
      'size': size,
    };
  }
}

void main() async {
  final apkMirrorDownloader = ApkMirrorDownloader();
  Map downloadPageMap = {};
  final apkInfo =
      await apkMirrorDownloader.getApkInfo('com.google.android.youtube', {});

  downloadPageMap =
      await apkMirrorDownloader.getApkDownloadUrl(apkInfo.downloadUrl!);

  print('''
  Name: ${apkInfo.name}
  Version: ${apkInfo.version}
  Size: ${downloadPageMap['size']}
  Download URL: ${downloadPageMap['downloadUrl']}
  ''');
}
