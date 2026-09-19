import 'package:flutter/material.dart';
import '../../../common_models/attachments/attachment_model.dart';

/// Full-screen gallery for complaint images, opened at [initialIndex].
class ImageGalleryViewerScreen extends StatefulWidget {
  final List<AttachmentModel> attachments;
  final int initialIndex;

  const ImageGalleryViewerScreen({
    super.key,
    required this.attachments,
    this.initialIndex = 0,
  });

  @override
  State<ImageGalleryViewerScreen> createState() =>
      _ImageGalleryViewerScreenState();
}

class _ImageGalleryViewerScreenState extends State<ImageGalleryViewerScreen> {
  late final PageController _controller = PageController(
    initialPage: widget.initialIndex,
  );
  late int _index = widget.initialIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_index + 1} / ${widget.attachments.length}'),
      ),
      body: PageView.builder(
        controller: _controller,
        itemCount: widget.attachments.length,
        onPageChanged: (i) => setState(() => _index = i),
        itemBuilder: (context, i) {
          final attachment = widget.attachments[i];
          return InteractiveViewer(
            child: Center(
              child: attachment.isLocal
                  ? Image.file(attachment.file!, fit: BoxFit.contain)
                  : Image.network(attachment.url!, fit: BoxFit.contain),
            ),
          );
        },
      ),
    );
  }
}
