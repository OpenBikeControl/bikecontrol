import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart' show Rect;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../workout/past_workout.dart';

/// "BikeControl 2026-10-05 1756.fit": what a saved or shared ride is called
/// outside the app.
String rideExportFileName(PastWorkout ride) {
  final d = ride.startedAt.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return 'BikeControl ${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}${two(d.minute)}.fit';
}

/// The platform side of exporting a ride's .fit: the share sheet, the save
/// dialog (Files on iOS, the system picker on Android, a save panel on
/// desktop) and the rides folder. One seam so widget tests swap in a fake.
abstract class RideFileActions {
  static RideFileActions instance = PlatformRideFileActions();

  /// True once the file went somewhere (the share sheet does not always
  /// tell; a dismissed sheet is false).
  Future<bool> share(PastWorkout ride, Uint8List bytes, {Rect? origin});

  /// The saved path, or null when the rider cancelled.
  Future<String?> save(PastWorkout ride, Uint8List bytes, {required String dialogTitle});

  Future<void> openFolder(Directory dir);
}

class PlatformRideFileActions implements RideFileActions {
  @override
  Future<bool> share(PastWorkout ride, Uint8List bytes, {Rect? origin}) async {
    // From data, not the stored path: only then does the share sheet carry
    // the readable name rather than "workout-20261005T155600Z.fit".
    final result = await SharePlus.instance.share(
      ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'application/octet-stream')],
        fileNameOverrides: [rideExportFileName(ride)],
        sharePositionOrigin: origin,
      ),
    );
    return result.status != ShareResultStatus.dismissed;
  }

  @override
  Future<String?> save(PastWorkout ride, Uint8List bytes, {required String dialogTitle}) =>
      FilePicker.platform.saveFile(
        dialogTitle: dialogTitle,
        fileName: rideExportFileName(ride),
        type: FileType.custom,
        allowedExtensions: const ['fit'],
        bytes: bytes,
      );

  @override
  Future<void> openFolder(Directory dir) async {
    await launchUrl(Uri.file(dir.path));
  }
}
