// Copyright 2020, the Chromium project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'package:cloud_firestore_platform_interface/cloud_firestore_platform_interface.dart';

import '../utils/codec_utility.dart';
import '../interop/firestore.dart' as firestore_interop;

const _kChangeTypeAdded = 'added';
const _kChangeTypeModified = 'modified';
const _kChangeTypeRemoved = 'removed';

/// Converts a [web.QuerySnapshot] to a [QuerySnapshotPlatform].
QuerySnapshotPlatform convertWebQuerySnapshot(
    FirebaseFirestorePlatform firestore,
    firestore_interop.QuerySnapshot webQuerySnapshot) {
  return QuerySnapshotPlatform(
    webQuerySnapshot.docs
        .map((webDocumentSnapshot) =>
            convertWebDocumentSnapshot(firestore, webDocumentSnapshot!))
        .toList(),
    webQuerySnapshot
        .docChanges()
        .map((webDocumentChange) =>
            convertWebDocumentChange(firestore, webDocumentChange))
        .toList(),
    convertWebSnapshotMetadata(webQuerySnapshot.metadata),
  );
}

/// Converts a [web.DocumentSnapshot] to a [DocumentSnapshotPlatform].
DocumentSnapshotPlatform convertWebDocumentSnapshot(
    FirebaseFirestorePlatform firestore,
    firestore_interop.DocumentSnapshot webSnapshot) {
  return DocumentSnapshotPlatform(
    firestore,
    webSnapshot.ref!.path,
    <String, dynamic>{
      'data': CodecUtility.decodeMapData(webSnapshot.data()),
      'metadata': <String, bool>{
        'hasPendingWrites': webSnapshot.metadata.hasPendingWrites,
        'isFromCache': webSnapshot.metadata.fromCache,
      },
    },
  );
}

/// Converts a [web.DocumentChange] to a [DocumentChangePlatform].
DocumentChangePlatform convertWebDocumentChange(
    FirebaseFirestorePlatform firestore,
    firestore_interop.DocumentChange webDocumentChange) {
  return DocumentChangePlatform(
      convertWebDocumentChangeType(webDocumentChange.type),
      webDocumentChange.oldIndex as int,
      webDocumentChange.newIndex as int,
      convertWebDocumentSnapshot(firestore, webDocumentChange.doc!));
}

/// Converts a [web.DocumentChange] type into a [DocumentChangeType].
DocumentChangeType convertWebDocumentChangeType(String changeType) {
  switch (changeType.toLowerCase()) {
    case _kChangeTypeAdded:
      return DocumentChangeType.added;
    case _kChangeTypeModified:
      return DocumentChangeType.modified;
    case _kChangeTypeRemoved:
      return DocumentChangeType.removed;
    default:
      throw FallThroughError();
  }
}

/// Converts a [web.SnapshotMetadata] to a [SnapshotMetadataPlatform].
SnapshotMetadataPlatform convertWebSnapshotMetadata(
    firestore_interop.SnapshotMetadata webSnapshotMetadata) {
  return SnapshotMetadataPlatform(
      webSnapshotMetadata.hasPendingWrites, webSnapshotMetadata.fromCache);
}

/// Converts a [GetOptions] to a [web.GetOptions].
firestore_interop.GetOptions? convertGetOptions(GetOptions? options) {
  if (options == null) return null;

  String? source;

  switch (options.source) {
    case Source.serverAndCache:
      source = 'default';
      break;
    case Source.cache:
      source = 'cache';
      break;
    case Source.server:
      source = 'server';
      break;
    default:
      source = 'default';
      break;
  }

  return firestore_interop.GetOptions(source: source);
}

/// Converts a [SetOptions] to a [web.SetOptions].
firestore_interop.SetOptions? convertSetOptions(SetOptions? options) {
  if (options == null) return null;

  firestore_interop.SetOptions? parsedOptions;
  if (options.merge != null) {
    parsedOptions = firestore_interop.SetOptions(merge: options.merge);
  } else if (options.mergeFields != null) {
    parsedOptions = firestore_interop.SetOptions(
        mergeFields: options.mergeFields!
            .map((e) => e.components.toList().join('.'))
            .toList());
  }

  return parsedOptions;
}

/// Converts a [FieldPath] to a [web.FieldPath].
firestore_interop.FieldPath convertFieldPath(FieldPath fieldPath) {
  return firestore_interop.FieldPath(fieldPath.components.toList().join('.'));
}

/// Will return a [FirebaseException] from a thrown web error.
/// Any other errors will be propagated as normal.
R guard<R>(R Function() cb) {
  try {
    return cb();
  } catch (error, stack) {
    if (error is! core_interop.FirebaseError) {
      rethrow;
    }

    String code = error.code.replaceFirst('firestore/', '');
    String message = error.message.replaceFirst('(${error.code})', '');
    throw FirebaseException(
        plugin: 'cloud_firestore', code: code, message: message);
  }
}