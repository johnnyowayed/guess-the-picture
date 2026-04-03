import 'dart:io';

import 'package:flutter/material.dart';

import '../services/storage_service.dart';

class LevelImage extends StatefulWidget {
  const LevelImage({
    super.key,
    required this.imagePath,
    this.onImageReady,
  });

  final String imagePath;
  final VoidCallback? onImageReady;

  @override
  State<LevelImage> createState() => _LevelImageState();
}

class _LevelImageState extends State<LevelImage> {
  final StorageService _storageService = StorageService();
  late Future<File> _imageFileFuture;
  bool _didNotifyReady = false;

  @override
  void initState() {
    super.initState();
    _imageFileFuture = _storageService.getOrDownloadImage(widget.imagePath);
  }

  @override
  void didUpdateWidget(covariant LevelImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath) {
      _didNotifyReady = false;
      _imageFileFuture = _storageService.getOrDownloadImage(widget.imagePath);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: _imageFileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const AspectRatio(
            aspectRatio: 1,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final imageFile = snapshot.data;
        if (snapshot.hasError || imageFile == null) {
          return const AspectRatio(
            aspectRatio: 1,
            child: Center(
              child: Icon(Icons.broken_image_outlined, size: 48),
            ),
          );
        }

        if (!_didNotifyReady) {
          _didNotifyReady = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            widget.onImageReady?.call();
          });
        }

        return AspectRatio(
          aspectRatio: 1,
          child: Image.file(
            imageFile,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }
}
