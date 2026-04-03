import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class StorageService {
  StorageService({
    FirebaseStorage? storage,
    http.Client? client,
  })  : _storage = storage ?? FirebaseStorage.instance,
        _client = client ?? http.Client();

  final FirebaseStorage _storage;
  final http.Client _client;

  Future<String> getImageUrl(String imagePath) async {
    return _storage.ref(imagePath).getDownloadURL();
  }

  Future<File> getLocalImageFile(String imagePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDirectory = Directory('${directory.path}/level_images');

    if (!await imagesDirectory.exists()) {
      await imagesDirectory.create(recursive: true);
    }

    return File('${imagesDirectory.path}/$imagePath');
  }

  Future<File> getOrDownloadImage(String imagePath) async {
    final localFile = await getLocalImageFile(imagePath);
    if (await localFile.exists()) {
      return localFile;
    }

    final imageUrl = await getImageUrl(imagePath);
    final response = await _client.get(Uri.parse(imageUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download $imagePath');
    }

    return localFile.writeAsBytes(response.bodyBytes, flush: true);
  }

  Future<void> preloadImages(
    List<String> imagePaths, {
    void Function(int completed, int total)? onProgress,
  }) async {
    final total = imagePaths.length;
    var completed = 0;

    for (final imagePath in imagePaths) {
      await getOrDownloadImage(imagePath);
      completed += 1;
      onProgress?.call(completed, total);
    }
  }
}
