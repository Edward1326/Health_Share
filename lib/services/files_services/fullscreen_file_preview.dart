import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'dart:io';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:mime/mime.dart';

class FullscreenFilePreview extends StatefulWidget {
  final String fileName;
  final Uint8List bytes;

  const FullscreenFilePreview({
    super.key,
    required this.fileName,
    required this.bytes,
  });

  @override
  State<FullscreenFilePreview> createState() => _FullscreenFilePreviewState();
}

class _FullscreenFilePreviewState extends State<FullscreenFilePreview> {
  VideoPlayerController? _videoController;
  AudioPlayer? _audioPlayer;
  String? _mimeType;
  late String _extension;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _extension = widget.fileName.split('.').last.toLowerCase();
    _mimeType = lookupMimeType(widget.fileName);
    _prepareFile();
  }

  Future<void> _prepareFile() async {
    // If file should be opened with system app, open it automatically
    if (_shouldOpenWithSystemApp()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _openWithSystemApp();
      });
      return;
    }

    // Prepare for video/audio files that need initialization
    if (_mimeType?.startsWith('video/') == true) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${widget.fileName}');
      await file.writeAsBytes(widget.bytes);

      _videoController = VideoPlayerController.file(file)
        ..initialize().then((_) {
          setState(() {});
          _videoController?.play();
        });
    } else if (_mimeType?.startsWith('audio/') == true) {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${widget.fileName}');
      await file.writeAsBytes(widget.bytes);

      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setFilePath(file.path);
      _audioPlayer!.play();
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _audioPlayer?.dispose();
    super.dispose();
  }

  /// Check if file should be opened with system app
  bool _shouldOpenWithSystemApp() {
    const systemAppExtensions = [
      'pdf',
      'doc',
      'docx',
      'xls',
      'xlsx',
      'ppt',
      'pptx',
      'zip',
      'rar',
      '7z',
      'tar',
      'gz',
      'apk',
      'epub',
      'mobi',
    ];
    return systemAppExtensions.contains(_extension);
  }

  /// Open file with system app (using open_filex)
  Future<void> _openWithSystemApp() async {
    setState(() => _isLoading = true);

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/${widget.fileName}');
      await file.writeAsBytes(widget.bytes, flush: true);

      final result = await OpenFilex.open(file.path);

      if (result.type != ResultType.done) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open file: ${result.message}'),
              action: SnackBarAction(label: 'OK', onPressed: () {}),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening file: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    // If file should be opened with system app, show opening screen
    if (_shouldOpenWithSystemApp()) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: Text(
            widget.fileName,
            style: const TextStyle(color: Colors.white),
          ),
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: Center(
          child:
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(_getFileIcon(), size: 80, color: Colors.white70),
                      const SizedBox(height: 16),
                      Text(
                        widget.fileName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _formatFileSize(widget.bytes.length),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                        onPressed: _openWithSystemApp,
                        icon: const Icon(Icons.open_in_new),
                        label: Text('Open with ${_getAppTypeName()}'),
                      ),
                    ],
                  ),
        ),
      );
    }

    // For preview-able files
    if (_mimeType?.startsWith('image/') == true) {
      content = PhotoView(imageProvider: MemoryImage(widget.bytes));
    } else if (_mimeType?.startsWith('video/') == true &&
        _videoController != null &&
        _videoController!.value.isInitialized) {
      content = AspectRatio(
        aspectRatio: _videoController!.value.aspectRatio,
        child: VideoPlayer(_videoController!),
      );
    } else if (_mimeType?.startsWith('audio/') == true) {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.audiotrack, size: 100, color: Colors.white70),
          const SizedBox(height: 24),
          Text(
            widget.fileName,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          StreamBuilder<Duration?>(
            stream: _audioPlayer?.positionStream,
            builder: (context, snapshot) {
              final position = snapshot.data ?? Duration.zero;
              final duration = _audioPlayer?.duration ?? Duration.zero;
              return Column(
                children: [
                  Text(
                    '${_formatDuration(position)} / ${_formatDuration(duration)}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                  if (duration.inSeconds > 0)
                    Slider(
                      value: position.inSeconds.toDouble(),
                      max: duration.inSeconds.toDouble(),
                      onChanged: (value) {
                        _audioPlayer?.seek(Duration(seconds: value.toInt()));
                      },
                    ),
                ],
              );
            },
          ),
        ],
      );
    } else if (_isTextFile(_extension)) {
      content = _buildTextPreview();
    } else {
      content = _unsupportedFileView(context);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          widget.fileName,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(child: content),
    );
  }

  bool _isTextFile(String extension) {
    const textExtensions = [
      'txt',
      'json',
      'xml',
      'csv',
      'log',
      'md',
      'html',
      'css',
      'js',
    ];
    return textExtensions.contains(extension);
  }

  Widget _buildTextPreview() {
    try {
      final textContent = String.fromCharCodes(widget.bytes);
      return Container(
        color: Colors.white,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            textContent,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ),
      );
    } catch (e) {
      return Center(
        child: Text(
          'Error displaying text: $e',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }
  }

  IconData _getFileIcon() {
    if (_extension == 'pdf') return Icons.picture_as_pdf;
    if (['doc', 'docx'].contains(_extension)) return Icons.description;
    if (['xls', 'xlsx'].contains(_extension)) return Icons.table_chart;
    if (['ppt', 'pptx'].contains(_extension)) return Icons.slideshow;
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(_extension))
      return Icons.folder_zip;
    if (_extension == 'apk') return Icons.android;
    if (['epub', 'mobi'].contains(_extension)) return Icons.menu_book;
    return Icons.insert_drive_file;
  }

  String _getAppTypeName() {
    if (_extension == 'pdf') return 'PDF Viewer';
    if (['doc', 'docx'].contains(_extension)) return 'Document App';
    if (['xls', 'xlsx'].contains(_extension)) return 'Spreadsheet App';
    if (['ppt', 'pptx'].contains(_extension)) return 'Presentation App';
    if (['zip', 'rar', '7z', 'tar', 'gz'].contains(_extension))
      return 'Archive Manager';
    if (_extension == 'apk') return 'Package Installer';
    if (['epub', 'mobi'].contains(_extension)) return 'Ebook Reader';
    return 'External App';
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  Widget _unsupportedFileView(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.insert_drive_file, size: 80, color: Colors.white70),
        const SizedBox(height: 16),
        Text(
          'Preview not supported for .$_extension files',
          style: const TextStyle(color: Colors.white70, fontSize: 16),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white24,
            foregroundColor: Colors.white,
          ),
          onPressed: _openWithSystemApp,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open with another app'),
        ),
      ],
    );
  }
}
