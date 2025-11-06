// chat_ai_ui.dart - UI components and widgets for ChatAI
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:video_player/video_player.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'chat_ai_network.dart';

// Avatar state enum
enum AvatarState { hello, thinking, speaking, congrat, listening, idle }

// Video Thumbnail Widget
class VideoThumbnail extends StatefulWidget {
  final String videoUrl;
  const VideoThumbnail({Key? key, required this.videoUrl}) : super(key: key);

  @override
  State<VideoThumbnail> createState() => _VideoThumbnailState();
}

class _VideoThumbnailState extends State<VideoThumbnail> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      if (widget.videoUrl.startsWith('http')) {
        _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      } else {
        _controller = VideoPlayerController.file(File(widget.videoUrl));
      }

      await _controller.initialize();
      if (mounted) {
        setState(() {
          _initialized = true;
        });
      }
    } catch (e) {
      print('Error initializing video thumbnail: $e');
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.error, color: Colors.red),
      );
    }

    if (!_initialized) {
      return Container(
        width: 200,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      width: 200,
      height: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: VideoPlayer(_controller),
        ),
      ),
    );
  }
}

// Video Player Dialog
class VideoPlayerDialog extends StatefulWidget {
  final String videoUrl;
  final Color primaryColor;
  final VoidCallback onSave;

  const VideoPlayerDialog({
    Key? key,
    required this.videoUrl,
    required this.primaryColor,
    required this.onSave,
  }) : super(key: key);

  @override
  State<VideoPlayerDialog> createState() => _VideoPlayerDialogState();
}

class _VideoPlayerDialogState extends State<VideoPlayerDialog> {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _error = false;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _controller.initialize();
      _controller.addListener(() {
        if (mounted) {
          setState(() {
            _isPlaying = _controller.value.isPlaying;
          });
        }
      });
      if (mounted) {
        setState(() {
          _initialized = true;
        });
        _controller.play();
      }
    } catch (e) {
      print('Error initializing video: $e');
      if (mounted) {
        setState(() {
          _error = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 800, maxHeight: 600),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: widget.onSave,
                ),
              ],
            ),
            Expanded(
              child: _error
                  ? const Center(
                      child: Text(
                        'Không thể tải video',
                        style: TextStyle(color: Colors.white),
                      ),
                    )
                  : !_initialized
                      ? const Center(child: CircularProgressIndicator())
                      : Stack(
                          alignment: Alignment.center,
                          children: [
                            AspectRatio(
                              aspectRatio: _controller.value.aspectRatio,
                              child: VideoPlayer(_controller),
                            ),
                            if (!_isPlaying)
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.black45,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.play_arrow, size: 64, color: Colors.white),
                                  onPressed: () => _controller.play(),
                                ),
                              ),
                            if (_isPlaying)
                              Positioned(
                                bottom: 20,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.black45,
                                    shape: BoxShape.circle,
                                  ),
                                  child: IconButton(
                                    icon: const Icon(Icons.pause, size: 32, color: Colors.white),
                                    onPressed: () => _controller.pause(),
                                  ),
                                ),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

// Avatar Video Player Widget
class AvatarVideoPlayer extends StatefulWidget {
  final AvatarState state;
  final Map<AvatarState, List<String>> avatarVideos;

  const AvatarVideoPlayer({
    Key? key,
    required this.state,
    required this.avatarVideos,
  }) : super(key: key);

  @override
  State<AvatarVideoPlayer> createState() => _AvatarVideoPlayerState();
}

class _AvatarVideoPlayerState extends State<AvatarVideoPlayer> with SingleTickerProviderStateMixin {
  Player? _player;
  VideoController? _videoController;
  AvatarState? _currentState;
  String? _currentVideo;
  String _currentBubbleText = '';
  late AnimationController _dotAnimationController;
  late Animation<int> _dotAnimation;

  final Map<AvatarState, List<String>> _bubbleTexts = {
    AvatarState.hello: ['Xin chào!', 'Bạn muốn hỏi gì?', 'Chào bạn!', 'Tôi có thể giúp gì?'],
    AvatarState.listening: ['Bạn có thể thêm ảnh', 'Có thể đính kèm file', 'Thêm file nếu muốn'],
    AvatarState.thinking: ['🤔...'],
    AvatarState.speaking: ['💭...', '📢...'],
    AvatarState.congrat: ['❤️', '💙', '💚', '💛'],
    AvatarState.idle: ['Bạn có thể chuyển sang chế độ tạo ảnh', 'Tôi có thể giúp bạn tạo video!', 'Bạn muốn biết gì nào?'],
  };

  @override
  void initState() {
    super.initState();
    _dotAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _dotAnimation = IntTween(begin: 0, end: 3).animate(_dotAnimationController);
    _initializeVideo();
  }

  @override
  void didUpdateWidget(AvatarVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _initializeVideo();
      _updateBubbleText();
    }
  }

  void _updateBubbleText() {
    final texts = _bubbleTexts[widget.state] ?? [];
    if (texts.isNotEmpty) {
      setState(() {
        _currentBubbleText = texts[(DateTime.now().millisecondsSinceEpoch % texts.length)];
      });
    }
  }

  Future<void> _initializeVideo() async {
    final videos = widget.avatarVideos[widget.state];
    if (videos == null || videos.isEmpty) return;

    final selectedVideo = videos[(DateTime.now().millisecondsSinceEpoch % videos.length)];
    final videoUrl = 'https://storage.googleapis.com/times1/DocumentApp/avatar/$selectedVideo';

    if (_currentVideo == videoUrl && _currentState == widget.state) {
      return;
    }

    _currentVideo = videoUrl;
    _currentState = widget.state;
    _updateBubbleText();

    try {
      final newPlayer = Player();
      final newController = VideoController(newPlayer);

      await newPlayer.open(Media(videoUrl));
      newPlayer.setPlaylistMode(PlaylistMode.loop);

      if (mounted) {
        setState(() {
          _player?.dispose();
          _player = newPlayer;
          _videoController = newController;
        });
      } else {
        newPlayer.dispose();
      }
    } catch (e) {
      print('Error loading avatar video: $e');
    }
  }

  @override
  void dispose() {
    _dotAnimationController.dispose();
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        if (_videoController != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Video(
              controller: _videoController!,
              width: 200,
              height: 200,
            ),
          )
        else
          Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
        Positioned(
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(12),
            ),
            child: AnimatedBuilder(
              animation: _dotAnimation,
              builder: (context, child) {
                final dots = '.' * _dotAnimation.value;
                return Text(
                  '$_currentBubbleText$dots',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// Helper function to build formatted text with markdown-like styling
Widget buildFormattedText(String text, Color color) {
  final spans = <TextSpan>[];
  final boldPattern = RegExp(r'\*\*(.+?)\*\*');
  final codePattern = RegExp(r'`([^`]+)`');

  int lastIndex = 0;

  for (final match in boldPattern.allMatches(text)) {
    if (match.start > lastIndex) {
      spans.add(TextSpan(text: text.substring(lastIndex, match.start)));
    }
    spans.add(TextSpan(
      text: match.group(1),
      style: const TextStyle(fontWeight: FontWeight.bold),
    ));
    lastIndex = match.end;
  }

  if (lastIndex < text.length) {
    spans.add(TextSpan(text: text.substring(lastIndex)));
  }

  return RichText(
    text: TextSpan(
      style: TextStyle(color: color, fontSize: 14),
      children: spans,
    ),
  );
}

// Helper function to build table widget
Widget buildTable(List<List<String>> rows) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Table(
      border: TableBorder.all(color: Colors.grey.shade300),
      children: rows.map((row) {
        return TableRow(
          children: row.map((cell) {
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                cell,
                style: const TextStyle(fontSize: 13),
              ),
            );
          }).toList(),
        );
      }).toList(),
    ),
  );
}
