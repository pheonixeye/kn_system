import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../core/theme/app_theme.dart';
import 'image_viewer_dialog.dart';

class StagedImageFile {
  final String name;
  final Uint8List bytes;

  StagedImageFile({required this.name, required this.bytes});

  http.MultipartFile toMultipartFile({String field = 'images'}) {
    return http.MultipartFile.fromBytes(field, bytes, filename: name);
  }
}

class ImageDropzone extends StatefulWidget {
  final List<String> existingImages;
  final String Function(String filename)? getImageUrl;
  final Function(String filename)? onDeleteExistingImage;
  final Function(List<StagedImageFile> stagedFiles)? onFilesChanged;
  final bool readOnly;

  /// Header label, e.g. "Clinical Investigations & Images".
  final String title;

  /// Helper text shown under the drop zone.
  final String subtitle;

  /// Allowed file extensions passed to the picker.
  final List<String> acceptedExtensions;

  const ImageDropzone({
    super.key,
    this.existingImages = const [],
    this.getImageUrl,
    this.onDeleteExistingImage,
    this.onFilesChanged,
    this.readOnly = false,
    this.title = 'Clinical Investigations & Images',
    this.subtitle =
        'Supports PNG, JPG, WEBP, Scans, Lab Results & PDFs (up to 50MB each)',
    this.acceptedExtensions = const [
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'bmp',
      'pdf',
    ],
  });

  @override
  State<ImageDropzone> createState() => ImageDropzoneState();
}

class ImageDropzoneState extends State<ImageDropzone> {
  final List<StagedImageFile> _stagedFiles = [];
  bool _isHovering = false;

  List<StagedImageFile> get stagedFiles => _stagedFiles;

  void clearStaged() {
    setState(() {
      _stagedFiles.clear();
    });
    widget.onFilesChanged?.call(_stagedFiles);
  }

  Future<void> _pickFiles() async {
    if (widget.readOnly) return;
    try {
      final result = await FilePicker.pickFiles(
        // allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: widget.acceptedExtensions,
        // withData: true,
      );

      if (result.isNotEmpty) {
        final newFiles = <StagedImageFile>[];
        for (final file in result) {
          if (await file.readAsBytes() != []) {
            newFiles.add(
              StagedImageFile(name: file.name, bytes: await file.readAsBytes()),
            );
          }
        }
        setState(() {
          _stagedFiles.addAll(newFiles);
        });
        widget.onFilesChanged?.call(_stagedFiles);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking files: $e')));
      }
    }
  }

  void _removeStagedFile(int index) {
    setState(() {
      _stagedFiles.removeAt(index);
    });
    widget.onFilesChanged?.call(_stagedFiles);
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.existingImages.length + _stagedFiles.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.attach_file_rounded,
                  size: 18,
                  color: AppTheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: totalCount > 0
                        ? AppTheme.primaryLight
                        : AppTheme.slate100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$totalCount attached',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: totalCount > 0
                          ? AppTheme.primary
                          : AppTheme.slate500,
                    ),
                  ),
                ),
              ],
            ),
            if (!widget.readOnly)
              TextButton.icon(
                onPressed: _pickFiles,
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
                label: const Text('Add Files'),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Dropzone / Upload Box
        if (!widget.readOnly)
          MouseRegion(
            onEnter: (_) => setState(() => _isHovering = true),
            onExit: (_) => setState(() => _isHovering = false),
            child: InkWell(
              onTap: _pickFiles,
              borderRadius: BorderRadius.circular(10),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 24,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: _isHovering
                      ? AppTheme.primaryLight.withValues(alpha: 0.5)
                      : AppTheme.slate50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isHovering ? AppTheme.primary : AppTheme.slate200,
                    width: 1.5,
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 36,
                      color: _isHovering ? AppTheme.primary : AppTheme.slate400,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Click to upload or drag & drop clinical images here',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _isHovering
                            ? AppTheme.primary
                            : AppTheme.slate700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: TextStyle(fontSize: 11, color: AppTheme.slate400),
                    ),
                  ],
                ),
              ),
            ),
          ),

        if (totalCount > 0) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              // Existing PocketBase files
              ...widget.existingImages.map((filename) {
                final url = widget.getImageUrl?.call(filename);
                return _buildExistingImageCard(filename, url);
              }),

              // Newly staged files (pending save)
              ..._stagedFiles.asMap().entries.map((entry) {
                return _buildStagedImageCard(entry.key, entry.value);
              }),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildExistingImageCard(String filename, String? url) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.slate200),
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadow,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: url != null
                    ? SizedBox(
                        height: 95,
                        width: double.infinity,
                        child: Image.network(
                          url,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: AppTheme.slate100,
                            child: Center(
                              child: Icon(
                                Icons.insert_drive_file_outlined,
                                color: AppTheme.slate400,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container(
                        height: 95,
                        color: AppTheme.slate100,
                        child: Icon(Icons.image, color: AppTheme.slate400),
                      ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (url != null)
                      InkWell(
                        onTap: () => ImageViewerDialog.show(
                          context,
                          imageUrl: url,
                          title: filename,
                        ),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.fullscreen,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    if (!widget.readOnly &&
                        widget.onDeleteExistingImage != null) ...[
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: () =>
                            widget.onDeleteExistingImage?.call(filename),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              filename,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStagedImageCard(int index, StagedImageFile stagedFile) {
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(8),
                ),
                child: SizedBox(
                  height: 95,
                  width: double.infinity,
                  child: Image.memory(
                    stagedFile.bytes,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      color: AppTheme.primaryLight,
                      child: Center(
                        child: Icon(
                          Icons.insert_drive_file,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                left: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'NEW',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: InkWell(
                  onTap: () => _removeStagedFile(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.danger.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Text(
              stagedFile.name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
