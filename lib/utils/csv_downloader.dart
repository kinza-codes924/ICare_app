// Triggers a browser download of a CSV file.
// Web → csv_downloader_web.dart (Blob + anchor click)
// Mobile/Desktop → csv_downloader_stub.dart (no-op; not supported there)
export 'csv_downloader_web.dart' if (dart.library.io) 'csv_downloader_stub.dart';
