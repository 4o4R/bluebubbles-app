import 'package:bluebubbles/utils/logger/logger.dart';
import 'package:convert/convert.dart';
import 'package:flutter/services.dart';
import 'package:super_clipboard/src/standard_formats.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

Size getGifDimensions(Uint8List bytes) {
  String hexString = "";
  // Bytes 6 and 7 are the width bytes of a gif
  hexString += hex.encode(bytes.sublist(7, 8));
  hexString += hex.encode(bytes.sublist(6, 7));
  int width = int.parse(hexString, radix: 16);

  hexString = "";
  // Bytes 8 and 9 are the height bytes of a gif
  hexString += hex.encode(bytes.sublist(9, 10));
  hexString += hex.encode(bytes.sublist(8, 9));
  int height = int.parse(hexString, radix: 16);

  Logger.debug("Decoded GIF width: $width");
  Logger.debug("Decoded GIF height: $height");
  Size size = Size(width.toDouble(), height.toDouble());
  return size;
}

final Map<DataFormat, String> formatMap = {
  Formats.plainText: ".txt",
  Formats.htmlText: ".html",
  Formats.uri: "",
  Formats.fileUri: "",
  Formats.plainTextFile: ".txt",
  Formats.htmlFile: ".html",
  Formats.jpeg: ".jpg",
  Formats.png: ".png",
  Formats.svg: ".svg",
  Formats.gif: ".gif",
  Formats.webp: ".webp",
  Formats.tiff: ".tiff",
  Formats.bmp: ".bmp",
  Formats.ico: ".ico",
  Formats.heic: ".heic",
  Formats.heif: ".heif",
  Formats.mp4: ".mp4",
  Formats.mov: ".mov",
  Formats.m4v: ".m4v",
  Formats.avi: ".avi",
  Formats.mpeg: ".mpeg",
  Formats.webm: ".webm",
  Formats.ogg: ".ogg",
  Formats.wmv: ".wmv",
  Formats.flv: ".flv",
  Formats.mkv: ".mkv",
  Formats.ts: ".ts",
  Formats.mp3: ".mp3",
  Formats.oga: ".oga",
  Formats.aac: ".aac",
  Formats.wav: ".wav",
  Formats.pdf: ".pdf",
  Formats.doc: ".doc",
  Formats.docx: ".docx",
  Formats.csv: ".csv",
  Formats.xls: ".xls",
  Formats.xlsx: ".xlsx",
  Formats.ppt: ".ppt",
  Formats.pptx: ".pptx",
  Formats.rtf: ".rtf",
  Formats.json: ".json",
  Formats.zip: ".zip",
  Formats.tar: ".tar",
  Formats.gzip: ".gz",
  Formats.bzip2: ".bz2",
  Formats.xz: ".xz",
  Formats.rar: ".rar",
  Formats.jar: ".jar",
  Formats.sevenZip: ".7z",
  Formats.dmg: ".dmg",
  Formats.iso: ".iso",
  Formats.deb: ".deb",
  Formats.rpm: ".rpm",
  Formats.apk: ".apk",
  Formats.exe: ".exe",
  Formats.msi: ".msi",
  Formats.dll: ".dll",
  Formats.webUnknown: "",
};

String getFormatExtension(DataFormat format) {
  return formatMap[format] ?? "";
}
