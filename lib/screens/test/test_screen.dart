// lib/screens/test/speech_translation_test_screen.dart - IMPROVED WITH LANGUAGE SELECTION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import '../../services/google_speech_translation_service.dart';

class SpeechTranslationTestScreen extends StatefulWidget {
  const SpeechTranslationTestScreen({super.key});

  @override
  State<SpeechTranslationTestScreen> createState() => _SpeechTranslationTestScreenState();
}

class _SpeechTranslationTestScreenState extends State<SpeechTranslationTestScreen> {
  GoogleSpeechTranslationService? _speechService;
  final List<SpeechTranslationResult> _results = [];
  String _currentStatus = 'Ready';
  bool _isInitialized = false;

  // ✅ LANGUAGE SELECTION
  String _selectedInputLanguage = 'en'; // Language to speak
  List<String> _selectedOutputLanguages = ['vi', 'zh', 'ja']; // Languages to translate to

  final List<String> _supportedLanguages = [
    'vi', 'en', 'zh', 'ja', 'ko', 'th', 'es', 'fr', 'de'
  ];

  final Map<String, String> _languageNames = {
    'vi': 'Tiếng Việt 🇻🇳',
    'en': 'English 🇺🇸',
    'zh': 'Chinese 🇨🇳',
    'ja': 'Japanese 🇯🇵',
    'ko': 'Korean 🇰🇷',
    'th': 'Thai 🇹🇭',
    'es': 'Spanish 🇪🇸',
    'fr': 'French 🇫🇷',
    'de': 'German 🇩🇪',
  };

  @override
  void initState() {
    super.initState();
    _initializeService();
  }

  Future<void> _initializeService() async {
    try {
      // ✅ FIX: Use Provider service instead of creating new instance
      _speechService = context.read<GoogleSpeechTranslationService>();

      // Setup user context
      _speechService!.setUserContext('test_user', 'Test User');
      _speechService!.setTranslationContext('test_meeting');
      _speechService!.setPreferredLanguage(_selectedInputLanguage);
      _speechService!.setTargetLanguages(_selectedOutputLanguages);

      // Listen to results
      _speechService!.resultStream.listen((result) {
        setState(() {
          _results.insert(0, result);
          if (_results.length > 20) {
            _results.removeRange(20, _results.length);
          }
        });
      });

      // Listen to status
      _speechService!.statusStream.listen((status) {
        setState(() {
          _currentStatus = status;
        });
      });

      // Initialize service if not already done
      if (!_speechService!.isInitialized) {
        await _speechService!.initialize();
      }

      setState(() {
        _isInitialized = true;
        _currentStatus = '✅ Ready to test (Real-time Mode)';
      });

    } catch (e) {
      setState(() {
        _currentStatus = '❌ Initialization failed: $e';
      });
      print('❌ Service initialization error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      appBar: AppBar(
        backgroundColor: GcbAppTheme.surface,
        title: const Row(
          children: [
            Icon(Icons.speed, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text(
              'Real-time Speech Translation',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Status and Controls
          _buildControlsSection(),

          // Results
          Expanded(child: _buildResultsSection()),
        ],
      ),
    );
  }

  Widget _buildControlsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: GcbAppTheme.surface,
        border: Border(
          bottom: BorderSide(color: Colors.grey[800]!),
        ),
      ),
      child: Column(
        children: [
          // Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(
                  _isInitialized
                      ? (_speechService?.isListening == true ? Icons.mic : Icons.mic_none)
                      : Icons.hourglass_empty,
                  color: _isInitialized
                      ? (_speechService?.isListening == true ? Colors.red : Colors.green)
                      : Colors.orange,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Service Status',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (_speechService?.isListening == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'LIVE',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        _currentStatus,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ✅ INPUT LANGUAGE SELECTION
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.mic, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Speaking Language (Input)',
                      style: TextStyle(
                        color: Colors.blue,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedInputLanguage,
                  dropdownColor: GcbAppTheme.surface,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.grey[800],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: _supportedLanguages.map((lang) => DropdownMenuItem(
                    value: lang,
                    child: Text(_languageNames[lang] ?? lang),
                  )).toList(),
                  onChanged: (newLang) {
                    if (newLang != null && _speechService != null) {
                      setState(() {
                        _selectedInputLanguage = newLang;
                      });
                      _speechService!.setPreferredLanguage(newLang);
                    }
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ✅ OUTPUT LANGUAGES SELECTION
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.translate, color: Colors.green, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Translation Languages (Output)',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _supportedLanguages.map((lang) {
                    final isSelected = _selectedOutputLanguages.contains(lang);
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selectedOutputLanguages.remove(lang);
                          } else {
                            _selectedOutputLanguages.add(lang);
                          }
                        });
                        _speechService?.setTargetLanguages(_selectedOutputLanguages);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.green.withOpacity(0.3)
                              : Colors.grey[800],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? Colors.green : Colors.grey[600]!,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isSelected)
                              const Icon(Icons.check, color: Colors.green, size: 14),
                            if (isSelected) const SizedBox(width: 4),
                            Text(
                              _languageNames[lang] ?? lang,
                              style: TextStyle(
                                color: isSelected ? Colors.green : Colors.grey[300],
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                if (_selectedOutputLanguages.isEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.orange, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Select at least one translation language',
                          style: TextStyle(color: Colors.orange, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Control Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isInitialized &&
                      _speechService?.isListening != true &&
                      _selectedOutputLanguages.isNotEmpty
                      ? _startListening
                      : null,
                  icon: const Icon(Icons.mic, size: 20),
                  label: const Text('Start Real-time'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _speechService?.isListening == true
                      ? _stopListening
                      : null,
                  icon: const Icon(Icons.stop, size: 20),
                  label: const Text('Stop Listening'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Additional actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isInitialized ? _downloadModels : null,
                  icon: const Icon(Icons.download, size: 16),
                  label: const Text('Download Models'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _results.clear();
                    });
                  },
                  icon: const Icon(Icons.clear, size: 16),
                  label: const Text('Clear Results'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.history, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Real-time Translation Results',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_results.length} results',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Expanded(
            child: _results.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) => _buildResultCard(_results[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_off,
            size: 64,
            color: Colors.grey[600],
          ),
          const SizedBox(height: 16),
          Text(
            'No speech results yet',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select languages and start listening\nto see real-time translation',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(SpeechTranslationResult result) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: GcbAppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.green.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(
                Icons.person,
                color: Colors.blue,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                result.userName,
                style: const TextStyle(
                  color: Colors.blue,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _languageNames[result.detectedLanguage]?.split(' ').first ?? result.detectedLanguage.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                result.isFromGoogleSpeech ? Icons.cloud : Icons.phone_android,
                color: Colors.green,
                size: 16,
              ),
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'REAL-TIME',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Original text
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Original:',
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  result.originalText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Translations
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Translations (${result.translations.length}):',
                  style: const TextStyle(
                    color: Colors.green,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                ...result.translations.entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _languageNames[entry.key]?.split(' ').first ?? entry.key.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Metadata
          Row(
            children: [
              const Icon(Icons.schedule, color: Colors.grey, size: 12),
              const SizedBox(width: 4),
              Text(
                _formatTime(result.timestamp),
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const SizedBox(width: 16),
              const Icon(Icons.analytics, color: Colors.grey, size: 12),
              const SizedBox(width: 4),
              Text(
                'Confidence: ${(result.confidence * 100).toInt()}%',
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
              const Spacer(),
              if (result.isFromGoogleSpeech)
                const Text(
                  'Google Speech',
                  style: TextStyle(color: Colors.green, fontSize: 11),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
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

  Future<void> _startListening() async {
    try {
      await _speechService?.startListening(
        meetingId: 'test_meeting',
        userId: 'test_user',
        preferredLanguage: _selectedInputLanguage,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start listening: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechService?.stopListening();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to stop listening: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _downloadModels() async {
    try {
      for (final lang in _supportedLanguages) {
        await _speechService?.downloadTranslationModel(lang);
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Translation models downloaded successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to download models: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    // Don't dispose the service since it's from Provider
    super.dispose();
  }
}