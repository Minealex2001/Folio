import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import '../../models/folio_page_template.dart';

const String kCommunityTemplatesCollection = 'communityTemplates';

/// Metadatos de una plantilla en la tienda comunitaria (Firestore + Storage).
class CommunityTemplateEntry {
  const CommunityTemplateEntry({
    required this.docId,
    required this.ownerUid,
    required this.name,
    required this.description,
    required this.emoji,
    required this.category,
    required this.blockCount,
    required this.storagePath,
    required this.storageDownloadUrl,
    this.createdAt,
  });

  final String docId;
  final String ownerUid;
  final String name;
  final String description;
  final String emoji;
  final String category;
  final int blockCount;
  final String storagePath;
  final String storageDownloadUrl;
  final DateTime? createdAt;

  static CommunityTemplateEntry? fromDoc(
    String docId,
    Map<String, dynamic> data,
  ) {
    final ownerUid = data['ownerUid']?.toString() ?? '';
    final name = data['name']?.toString() ?? '';
    final storagePath = data['storagePath']?.toString() ?? '';
    final url = data['storageDownloadUrl']?.toString() ?? '';
    if (ownerUid.isEmpty || name.isEmpty || storagePath.isEmpty || url.isEmpty) {
      return null;
    }
    DateTime? createdAt;
    final rawCreated = data['createdAt'];
    if (rawCreated is Timestamp) {
      createdAt = rawCreated.toDate();
    }
    final blockCount = (data['blockCount'] as num?)?.toInt() ?? 0;
    return CommunityTemplateEntry(
      docId: docId,
      ownerUid: ownerUid,
      name: name,
      description: data['description']?.toString() ?? '',
      emoji: data['emoji']?.toString() ?? '',
      category: data['category']?.toString() ?? '',
      blockCount: blockCount,
      storagePath: storagePath,
      storageDownloadUrl: url,
      createdAt: createdAt,
    );
  }
}

class CommunityTemplateStore {
  CommunityTemplateStore({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static bool get isFirebaseReady => Firebase.apps.isNotEmpty;

  /// Sube la plantilla y crea el documento índice. [tpl] puede tener cualquier id local;
  /// el archivo publicado usa [docId] como id Folio en el JSON.
  Future<String> publishTemplate(FolioPageTemplate tpl) async {
    if (!isFirebaseReady) {
      throw StateError('Firebase not initialized');
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    const uuid = Uuid();
    final docId = uuid.v4();
    final path = 'community-templates/${user.uid}/$docId.folio-template';
    final published = FolioPageTemplate(
      id: docId,
      name: tpl.name,
      description: tpl.description,
      emoji: tpl.emoji,
      category: tpl.category,
      createdAtMs: tpl.createdAtMs,
      blocks: tpl.blocks,
    );
    final bytes = utf8.encode(published.encodeAsFile());
    final ref = FirebaseStorage.instance.ref().child(path);
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'application/json; charset=utf-8'),
    );
    final downloadUrl = await ref.getDownloadURL();
    final batch = <String, dynamic>{
      'ownerUid': user.uid,
      'name': tpl.name.trim().isEmpty ? 'Template' : tpl.name.trim(),
      'description': tpl.description.trim(),
      'category': tpl.category.trim(),
      'blockCount': tpl.blocks.length,
      'storagePath': path,
      'storageDownloadUrl': downloadUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final emoji = tpl.emoji?.trim() ?? '';
    if (emoji.isNotEmpty) {
      batch['emoji'] = emoji;
    }
    await _firestore
        .collection(kCommunityTemplatesCollection)
        .doc(docId)
        .set(batch);
    return docId;
  }

  /// Listado reciente para la galería (sin filtro Firestore por categoría; filtrar en cliente).
  Future<List<CommunityTemplateEntry>> listRecent({int limit = 80}) async {
    if (!isFirebaseReady) {
      throw StateError('Firebase not initialized');
    }
    final snap = await _firestore
        .collection(kCommunityTemplatesCollection)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    final out = <CommunityTemplateEntry>[];
    for (final d in snap.docs) {
      final e = CommunityTemplateEntry.fromDoc(d.id, d.data());
      if (e != null) {
        out.add(e);
      }
    }
    return out;
  }

  /// Descarga el archivo público y parsea. No modifica el vault.
  Future<FolioPageTemplate> downloadTemplate(String downloadUrl) async {
    final response = await http.get(Uri.parse(downloadUrl));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('HTTP ${response.statusCode}');
    }
    final raw = utf8.decode(response.bodyBytes);
    final parsed = FolioPageTemplate.tryParseFile(raw);
    if (parsed == null) {
      throw const FormatException('Invalid community template file');
    }
    return parsed;
  }

  /// Copia al vault con id nuevo (misma semántica que importación desde archivo).
  FolioPageTemplate copyIntoVault(FolioPageTemplate parsed) {
    const uuid = Uuid();
    return FolioPageTemplate(
      id: uuid.v4(),
      name: parsed.name,
      description: parsed.description,
      emoji: parsed.emoji,
      category: parsed.category,
      createdAtMs: parsed.createdAtMs,
      blocks: parsed.blocks,
    );
  }

  Future<void> deleteMyTemplate({
    required String docId,
    required String storagePath,
  }) async {
    if (!isFirebaseReady) {
      throw StateError('Firebase not initialized');
    }
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('Not signed in');
    }
    final docRef = _firestore
        .collection(kCommunityTemplatesCollection)
        .doc(docId);
    final doc = await docRef.get();
    if (!doc.exists) {
      return;
    }
    final owner = doc.data()?['ownerUid']?.toString();
    if (owner != user.uid) {
      throw StateError('Not owner');
    }
    await FirebaseStorage.instance.ref().child(storagePath).delete();
    await docRef.delete();
  }
}
