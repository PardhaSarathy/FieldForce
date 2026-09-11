/// Private-bucket uploads that follow `{org_id}/{employee_id}/{uuid}.ext`.
///
/// Mirrors [ApiChatRepository.sendImage]: size cap, mime → extension, and
/// `uploadBinary` with an explicit content type. Callers store the returned
/// path on the row (receipt_paths, photo_paths, attachment_paths).
library;

import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import 'backend.dart';

const _maxUploadBytes = 8 * 1024 * 1024;
const _uuid = Uuid();

String extensionForMime(String mimeType) => switch (mimeType) {
      'image/png' => 'png',
      'image/webp' => 'webp',
      'image/heic' => 'heic',
      'application/pdf' => 'pdf',
      _ => 'jpg',
    };

/// Upload bytes to a private org bucket. Path layout matches 0029 policies.
Future<String> uploadOrgEmployeeFile({
  required String bucket,
  required List<int> bytes,
  required String mimeType,
  String fileName = 'photo.jpg',
}) async {
  if (bytes.length > _maxUploadBytes) {
    throw StateError('That file is larger than 8 MB.');
  }
  final orgId = await db.rpc('current_org_id');
  final employeeId = await db.rpc('current_employee_id');
  if (orgId == null || employeeId == null) {
    throw StateError('Not signed in as a field person.');
  }
  final ext = extensionForMime(mimeType);
  final path = '$orgId/$employeeId/${_uuid.v4()}.$ext';
  await db.storage.from(bucket).uploadBinary(
        path,
        Uint8List.fromList(bytes),
        fileOptions: sb.FileOptions(
          contentType: mimeType.isEmpty ? 'image/jpeg' : mimeType,
          upsert: true,
        ),
      );
  return path;
}

/// Short label for a storage path or fixture stub (last path segment).
String storageDisplayName(String path) {
  final slash = path.lastIndexOf('/');
  return slash < 0 ? path : path.substring(slash + 1);
}
