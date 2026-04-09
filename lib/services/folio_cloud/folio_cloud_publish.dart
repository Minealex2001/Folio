import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';

import 'folio_cloud_entitlements.dart';

class FolioPublishResult {
  const FolioPublishResult({required this.publicUrl, required this.docId});

  final Uri publicUrl;
  final String docId;
}

class PublishedPageEntry {
  const PublishedPageEntry({
    required this.docId,
    required this.slug,
    required this.publicUrl,
    required this.storagePath,
    this.updatedAt,
  });

  final String docId;
  final String slug;
  final String publicUrl;
  final String storagePath;
  final DateTime? updatedAt;
}

void _requirePublishWebEntitlement(FolioCloudSnapshot? snapshot) {
  if (snapshot != null && !snapshot.canPublishToWeb) {
    throw StateError(
      'Tu plan Folio Cloud no incluye publicación web o la suscripción no está activa.',
    );
  }
}

/// Publishes HTML to public Storage path and indexes metadata in Firestore.
/// Si [entitlementSnapshot] no es null, comprueba [FolioCloudSnapshot.canPublishToWeb].
Future<FolioPublishResult> publishHtmlPage({
  required String slug,
  required String html,
  FolioCloudSnapshot? entitlementSnapshot,
}) async {
  _requirePublishWebEntitlement(entitlementSnapshot);
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Not signed in');
  final safeSlug = slug.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '-');
  if (safeSlug.isEmpty) {
    throw ArgumentError('Invalid slug');
  }
  final path = 'published/${user.uid}/$safeSlug.html';
  final ref = FirebaseStorage.instance.ref().child(path);
  await ref.putData(
    utf8.encode(html),
    SettableMetadata(contentType: 'text/html; charset=utf-8'),
  );
  final url = await ref.getDownloadURL();
  final uri = Uri.parse(url);
  final docId = '${user.uid}_$safeSlug';
  await FirebaseFirestore.instance.collection('publishedPages').doc(docId).set({
    'ownerUid': user.uid,
    'slug': safeSlug,
    'storagePath': path,
    'publicUrl': url,
    'updatedAt': FieldValue.serverTimestamp(),
  });
  return FolioPublishResult(publicUrl: uri, docId: docId);
}

/// Entradas de [publishedPages] del usuario actual (orden aproximado por [updatedAt] en cliente).
Future<List<PublishedPageEntry>> listMyPublishedPages() async {
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Not signed in');
  final qs = await FirebaseFirestore.instance
      .collection('publishedPages')
      .where('ownerUid', isEqualTo: user.uid)
      .get();
  final out = <PublishedPageEntry>[];
  for (final d in qs.docs) {
    final m = d.data();
    final slug = m['slug']?.toString() ?? '';
    final url = m['publicUrl']?.toString() ?? '';
    final storagePath = m['storagePath']?.toString() ?? '';
    if (slug.isEmpty || url.isEmpty) continue;
    DateTime? updatedAt;
    final raw = m['updatedAt'];
    if (raw is Timestamp) {
      updatedAt = raw.toDate();
    }
    out.add(
      PublishedPageEntry(
        docId: d.id,
        slug: slug,
        publicUrl: url,
        storagePath: storagePath,
        updatedAt: updatedAt,
      ),
    );
  }
  out.sort((a, b) {
    final ta = a.updatedAt;
    final tb = b.updatedAt;
    if (ta == null && tb == null) return 0;
    if (ta == null) return 1;
    if (tb == null) return -1;
    return tb.compareTo(ta);
  });
  return out;
}

/// Quita el HTML en Storage y el índice en Firestore.
Future<void> deletePublishedPage(
  PublishedPageEntry entry, {
  FolioCloudSnapshot? entitlementSnapshot,
}) async {
  _requirePublishWebEntitlement(entitlementSnapshot);
  if (Firebase.apps.isEmpty) {
    throw StateError('Firebase not initialized');
  }
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw StateError('Not signed in');
  if (entry.storagePath.isNotEmpty) {
    try {
      await FirebaseStorage.instance.ref(entry.storagePath).delete();
    } catch (_) {
      // Puede no existir; seguimos borrando el índice.
    }
  }
  await FirebaseFirestore.instance
      .collection('publishedPages')
      .doc(entry.docId)
      .delete();
}
