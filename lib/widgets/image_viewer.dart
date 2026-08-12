import 'package:flutter/material.dart';
import 'fade_route.dart';

class ImageViewer extends StatefulWidget {
  final String imagePath;
  final String heroTag;

  const ImageViewer({
    super.key,
    required this.imagePath,
    required this.heroTag,
  });

  static void show(BuildContext context, String imagePath, String heroTag) {
    Navigator.of(context).push(
      FadeRoute(
        page: ImageViewer(imagePath: imagePath, heroTag: heroTag),
      ),
    );
  }

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  final TransformationController _transformCtrl = TransformationController();

  @override
  void dispose() {
    _transformCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          transformationController: _transformCtrl,
          minScale: 0.5,
          maxScale: 5.0,
          child: Hero(
            tag: widget.heroTag,
            child: Image.asset(
              widget.imagePath,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Center(
                child: Text('Image not found', style: TextStyle(color: Colors.white54)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
