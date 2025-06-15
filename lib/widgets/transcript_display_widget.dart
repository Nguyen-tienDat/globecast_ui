// lib/widgets/transcript_display_widget.dart
import 'package:flutter/material.dart';
import '../services/whisper_service.dart';

class TranscriptDisplayWidget extends StatefulWidget {
  final WhisperService whisperService;
  final bool isVisible;
  final VoidCallback? onToggleVisibility;

  const TranscriptDisplayWidget({
    Key? key,
    required this.whisperService,
    this.isVisible = true,
    this.onToggleVisibility,
  }) : super(key: key);

  @override
  State<TranscriptDisplayWidget> createState() => _TranscriptDisplayWidgetState();
}

class _TranscriptDisplayWidgetState extends State<TranscriptDisplayWidget> {
  final List<TranscriptionResult> _transcripts = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Listen to transcription stream
    widget.whisperService.transcriptionStream.listen((result) {
      setState(() {
        _transcripts.add(result);
      });

      // Auto-scroll to bottom
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(12),
      ),
      constraints: const BoxConstraints(
        maxHeight: 250,
        minHeight: 100,
      ),
      margin: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Colors.blue,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.subtitles, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Text(
                  'Live Transcription',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                StreamBuilder<WhisperConnectionState>(
                  stream: widget.whisperService.connectionStateStream,
                  builder: (context, snapshot) {
                    final state = snapshot.data ?? WhisperConnectionState.disconnected;
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getConnectionColor(state),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                if (widget.onToggleVisibility != null)
                  GestureDetector(
                    onTap: widget.onToggleVisibility,
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
              ],
            ),
          ),

          // Transcript content
          Expanded(
            child: _transcripts.isEmpty
                ? const Center(
              child: Text(
                'Waiting for speech...',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            )
                : ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(8),
              itemCount: _transcripts.length,
              itemBuilder: (context, index) {
                final transcript = _transcripts[index];
                return _buildTranscriptItem(transcript);
              },
            ),
          ),

          // Footer with stats
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Total: ${_transcripts.length} messages',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                StreamBuilder<WhisperConnectionState>(
                  stream: widget.whisperService.connectionStateStream,
                  builder: (context, snapshot) {
                    final state = snapshot.data ?? WhisperConnectionState.disconnected;
                    return Text(
                      _getConnectionText(state),
                      style: TextStyle(
                        color: _getConnectionColor(state),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptItem(TranscriptionResult transcript) {
    final isTranslated = transcript.originalText != transcript.translatedText;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: isTranslated
            ? Border.all(color: Colors.orange.withOpacity(0.5), width: 1)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Speaker and timestamp
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  transcript.speakerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatTimestamp(transcript.timestamp),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 11,
                ),
              ),
              const Spacer(),
              if (isTranslated)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${transcript.originalLanguage.toUpperCase()} → ${transcript.targetLanguage.toUpperCase()}',
                    style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Original text (if translated)
          if (isTranslated) ...[
            Text(
              transcript.originalText,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
          ],

          // Translated/final text
          Text(
            transcript.translatedText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              height: 1.3,
            ),
          ),

          // Quality indicators
          const SizedBox(height: 6),
          Row(
            children: [
              _buildQualityIndicator(
                'Audio',
                transcript.audioQuality,
                Colors.green,
              ),
              const SizedBox(width: 12),
              _buildQualityIndicator(
                'Transcript',
                transcript.transcriptionConfidence,
                Colors.blue,
              ),
              if (isTranslated) ...[
                const SizedBox(width: 12),
                _buildQualityIndicator(
                  'Translation',
                  transcript.translationConfidence,
                  Colors.orange,
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQualityIndicator(String label, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 30,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.grey[700],
            borderRadius: BorderRadius.circular(2),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Color _getConnectionColor(WhisperConnectionState state) {
    switch (state) {
      case WhisperConnectionState.connected:
        return Colors.green;
      case WhisperConnectionState.connecting:
      case WhisperConnectionState.reconnecting:
        return Colors.orange;
      case WhisperConnectionState.error:
        return Colors.red;
      case WhisperConnectionState.disconnected:
        return Colors.grey;
    }
  }

  String _getConnectionText(WhisperConnectionState state) {
    switch (state) {
      case WhisperConnectionState.connected:
        return 'Connected';
      case WhisperConnectionState.connecting:
        return 'Connecting...';
      case WhisperConnectionState.reconnecting:
        return 'Reconnecting...';
      case WhisperConnectionState.error:
        return 'Error';
      case WhisperConnectionState.disconnected:
        return 'Disconnected';
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return '${diff.inSeconds}s ago';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}

// Floating transcript toggle button
class TranscriptToggleButton extends StatelessWidget {
  final bool isVisible;
  final VoidCallback onToggle;
  final int transcriptCount;

  const TranscriptToggleButton({
    Key? key,
    required this.isVisible,
    required this.onToggle,
    this.transcriptCount = 0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 100,
      right: 16,
      child: GestureDetector(
        onTap: onToggle,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isVisible ? Colors.blue : Colors.grey[800],
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isVisible ? Icons.subtitles : Icons.subtitles_outlined,
                color: Colors.white,
                size: 20,
              ),
              if (transcriptCount > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    transcriptCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}