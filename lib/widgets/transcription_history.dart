// lib/widgets/transcription_history_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:globecast_ui/services/firebase_transcription_service.dart';
import 'package:globecast_ui/services/whisper_service.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:intl/intl.dart';

class TranscriptionHistoryWidget extends StatefulWidget {
  final String meetingId;
  final VoidCallback? onClose;

  const TranscriptionHistoryWidget({
    super.key,
    required this.meetingId,
    this.onClose,
  });

  @override
  State<TranscriptionHistoryWidget> createState() => _TranscriptionHistoryWidgetState();
}

class _TranscriptionHistoryWidgetState extends State<TranscriptionHistoryWidget> {
  final FirebaseTranscriptionService _firebaseService = FirebaseTranscriptionService();
  final ScrollController _scrollController = ScrollController();
  bool _autoScroll = true;
  String _searchQuery = '';
  String _selectedLanguage = 'all';

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: GcbAppTheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          _buildHeader(),

          // Search and filters
          _buildSearchAndFilters(),

          // Transcription list
          Expanded(
            child: _buildTranscriptionList(),
          ),

          // Stats footer
          _buildStatsFooter(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.history,
            color: GcbAppTheme.primary,
            size: 24,
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Transcription History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            children: [
              // Auto-scroll toggle
              IconButton(
                icon: Icon(
                  _autoScroll ? Icons.vertical_align_bottom : Icons.vertical_align_bottom_outlined,
                  color: _autoScroll ? GcbAppTheme.primary : Colors.grey,
                  size: 20,
                ),
                onPressed: () {
                  setState(() {
                    _autoScroll = !_autoScroll;
                  });
                  HapticFeedback.lightImpact();
                },
                tooltip: 'Auto-scroll to latest',
              ),

              // Close button
              if (widget.onClose != null)
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  onPressed: widget.onClose,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          // Search field
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(18),
              ),
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value.toLowerCase();
                  });
                },
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search transcriptions...',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[400], size: 18),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),

          // Language filter
          Container(
            height: 36,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(18),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedLanguage,
                icon: Icon(Icons.language, color: Colors.grey[400], size: 16),
                style: const TextStyle(color: Colors.white, fontSize: 12),
                dropdownColor: Colors.grey[800],
                items: [
                  const DropdownMenuItem(value: 'all', child: Text('All')),
                  ...WhisperService.supportedLanguages.entries.map(
                        (entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedLanguage = value ?? 'all';
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptionList() {
    return StreamBuilder<List<TranscriptionResult>>(
      stream: _firebaseService.getTranscriptionHistory(widget.meetingId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: GcbAppTheme.primary),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Error loading transcriptions',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final transcriptions = snapshot.data ?? [];

        if (transcriptions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.mic_off, color: Colors.grey[600], size: 48),
                const SizedBox(height: 16),
                Text(
                  'No transcriptions yet',
                  style: TextStyle(color: Colors.grey[400], fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start speaking to see transcriptions appear here',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          );
        }

        // Filter transcriptions
        final filteredTranscriptions = transcriptions.where((trans) {
          final matchesSearch = _searchQuery.isEmpty ||
              trans.translatedText.toLowerCase().contains(_searchQuery) ||
              trans.originalText.toLowerCase().contains(_searchQuery) ||
              trans.speakerName.toLowerCase().contains(_searchQuery);

          final matchesLanguage = _selectedLanguage == 'all' ||
              trans.originalLanguage == _selectedLanguage;

          return matchesSearch && matchesLanguage;
        }).toList();

        // Auto-scroll to bottom when new items arrive
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });

        return ListView.separated(
          controller: _scrollController,
          padding: const EdgeInsets.all(8),
          itemCount: filteredTranscriptions.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            return _buildTranscriptionItem(filteredTranscriptions[index]);
          },
        );
      },
    );
  }

  Widget _buildTranscriptionItem(TranscriptionResult transcription) {
    final timeFormat = DateFormat('HH:mm:ss');

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: transcription.transcriptionConfidence > 0.8
              ? Colors.green.withOpacity(0.3)
              : Colors.orange.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with speaker info
          Row(
            children: [
              // Speaker avatar
              CircleAvatar(
                radius: 12,
                backgroundColor: GcbAppTheme.primary,
                child: Text(
                  transcription.speakerName.isNotEmpty
                      ? transcription.speakerName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(fontSize: 12, color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),

              // Speaker name
              Expanded(
                child: Text(
                  transcription.speakerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              // Language badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: GcbAppTheme.primary.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  transcription.originalLanguage.toUpperCase(),
                  style: const TextStyle(
                    color: GcbAppTheme.primary,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 8),

              // Timestamp
              Text(
                timeFormat.format(transcription.timestamp),
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 11,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Transcription text
          GestureDetector(
            onTap: () {
              // Copy to clipboard
              Clipboard.setData(ClipboardData(text: transcription.translatedText));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Copied to clipboard'),
                  duration: Duration(seconds: 1),
                ),
              );
            },
            child: Text(
              transcription.translatedText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                height: 1.3,
              ),
            ),
          ),

          // Original text (if different)
          if (transcription.originalText != transcription.translatedText) ...[
            const SizedBox(height: 6),
            Text(
              'Original: ${transcription.originalText}',
              style: TextStyle(
                color: Colors.grey[400],
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // Confidence indicator
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                transcription.transcriptionConfidence > 0.8
                    ? Icons.check_circle
                    : transcription.transcriptionConfidence > 0.6
                    ? Icons.warning
                    : Icons.error,
                size: 12,
                color: transcription.transcriptionConfidence > 0.8
                    ? Colors.green
                    : transcription.transcriptionConfidence > 0.6
                    ? Colors.orange
                    : Colors.red,
              ),
              const SizedBox(width: 4),
              Text(
                '${(transcription.transcriptionConfidence * 100).toInt()}% confidence',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              Text(
                '${transcription.processingTime.toStringAsFixed(2)}s',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsFooter() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _firebaseService.getMeetingStats(widget.meetingId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final stats = snapshot.data!;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: Icons.transcribe,
                label: 'Total',
                value: '${stats['totalTranscriptions'] ?? 0}',
              ),
              _buildStatItem(
                icon: Icons.people,
                label: 'Speakers',
                value: '${stats['totalSpeakers'] ?? 0}',
              ),
              _buildStatItem(
                icon: Icons.language,
                label: 'Languages',
                value: '${(stats['languagesDetected'] as List?)?.length ?? 0}',
              ),
              _buildStatItem(
                icon: Icons.timer,
                label: 'Duration',
                value: '${(stats['totalDuration'] ?? 0.0).toStringAsFixed(1)}s',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Icon(icon, color: GcbAppTheme.primary, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}