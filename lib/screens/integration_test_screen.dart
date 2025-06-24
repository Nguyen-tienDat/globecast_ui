// lib/screens/integration_test_screen.dart - PURE WORKFLOW VERSION
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/integrated_meeting_service.dart';
import '../services/webrtc_mesh_meeting_service.dart';
import '../services/multilingual_speech_service.dart';
import '../services/audio_capture_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class IntegrationTestScreen extends StatefulWidget {
  const IntegrationTestScreen({super.key});

  @override
  State<IntegrationTestScreen> createState() => _IntegrationTestScreenState();
}

class _IntegrationTestScreenState extends State<IntegrationTestScreen> {
  late IntegratedMeetingService _integratedService;

  final TextEditingController _meetingIdController = TextEditingController(text: 'TEST${DateTime.now().millisecondsSinceEpoch % 10000}');
  final TextEditingController _userNameController = TextEditingController(text: 'Test User');

  String _selectedLanguage = 'en';
  bool _isInitialized = false;

  final List<String> _logMessages = [];
  final List<SpeechResult> _speechResults = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeIntegratedService();
    });
  }

  Future<void> _initializeIntegratedService() async {
    try {
      _addLog('🚀 Initializing Integrated Meeting Service...');

      final webrtcService = context.read<WebRTCMeshMeetingService>();
      final speechService = context.read<MultilingualSpeechService>();
      final audioService = context.read<AudioCaptureService>();
      final authService = context.read<AuthService>();

      _integratedService = IntegratedMeetingService(
        webrtcService: webrtcService,
        speechService: speechService,
        audioService: audioService,
        authService: authService,
      );

      // Listen to status updates
      _integratedService.statusStream.listen((status) {
        _addLog('📱 $status');
      });

      // Listen to speech results
      _integratedService.speechResultStream.listen((result) {
        setState(() {
          _speechResults.insert(0, result);
          if (_speechResults.length > 20) {
            _speechResults.removeLast();
          }
        });
        _addLog('🗣️ Original: ${result.originalText}');
        _addLog('🌐 Vietnamese: ${result.translations['vi'] ?? 'N/A'}');
        _addLog('🌐 Chinese: ${result.translations['zh'] ?? 'N/A'}');
      });

      _isInitialized = true;
      _addLog('✅ Integrated service initialized successfully');
      setState(() {});

    } catch (e) {
      _addLog('❌ Failed to initialize: $e');
    }
  }

  void _addLog(String message) {
    setState(() {
      final timestamp = DateTime.now().toIso8601String().split('T')[1].substring(0, 8);
      _logMessages.insert(0, '$timestamp - $message');
      if (_logMessages.length > 100) {
        _logMessages.removeLast();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      appBar: AppBar(
        backgroundColor: GcbAppTheme.surface,
        title: const Text(
          'Integration Test - Live Workflow',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          if (_isInitialized) _buildStatusIndicator(),
        ],
      ),
      body: _isInitialized ? _buildMainContent() : _buildLoadingScreen(),
      floatingActionButton: _isInitialized ? _buildActionButton() : null,
    );
  }

  Widget _buildStatusIndicator() {
    return Consumer<IntegratedMeetingService>(
      builder: (context, service, child) {
        final isActive = service.isInMeeting;
        return Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isActive ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive ? Colors.green : Colors.grey,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isActive ? Colors.green : Colors.grey,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isActive ? 'LIVE' : 'READY',
                style: TextStyle(
                  color: isActive ? Colors.green : Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: GcbAppTheme.primary),
          SizedBox(height: 16),
          Text(
            'Setting up workflow...',
            style: TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        // Configuration Panel
        Container(
          padding: const EdgeInsets.all(20),
          color: GcbAppTheme.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Meeting Configuration',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _meetingIdController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Meeting ID',
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _userNameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Your Name',
                        labelStyle: TextStyle(color: Colors.grey),
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedLanguage,
                      dropdownColor: GcbAppTheme.surface,
                      style: const TextStyle(color: Colors.white),
                      underline: Container(),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('🇺🇸 EN')),
                        DropdownMenuItem(value: 'vi', child: Text('🇻🇳 VI')),
                        DropdownMenuItem(value: 'zh', child: Text('🇨🇳 ZH')),
                        DropdownMenuItem(value: 'ja', child: Text('🇯🇵 JA')),
                        DropdownMenuItem(value: 'ko', child: Text('🇰🇷 KO')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _selectedLanguage = value;
                          });
                          if (_isInitialized) {
                            _integratedService.setLanguage(value);
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Live Results Panel
        Expanded(
          child: Row(
            children: [
              // Speech Results (Left)
              Expanded(
                flex: 2,
                child: Container(
                  color: GcbAppTheme.background,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: GcbAppTheme.surfaceLight,
                        child: Row(
                          children: [
                            const Icon(Icons.translate, color: Colors.blue, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Live Translations (${_speechResults.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => setState(() => _speechResults.clear()),
                              icon: const Icon(Icons.clear_all, color: Colors.grey, size: 20),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _speechResults.isEmpty
                            ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.mic_none,
                                size: 64,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Start workflow to see live translations',
                                style: TextStyle(color: Colors.grey[400]),
                              ),
                            ],
                          ),
                        )
                            : ListView.builder(
                          itemCount: _speechResults.length,
                          itemBuilder: (context, index) {
                            return _buildSpeechResultCard(_speechResults[index]);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Activity Log (Right)
              Expanded(
                flex: 1,
                child: Container(
                  color: GcbAppTheme.surface,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        color: GcbAppTheme.surfaceLight,
                        child: Row(
                          children: [
                            const Icon(Icons.list_alt, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Activity Log (${_logMessages.length})',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              onPressed: () => setState(() => _logMessages.clear()),
                              icon: const Icon(Icons.clear_all, color: Colors.grey, size: 20),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: _logMessages.isEmpty
                            ? Center(
                          child: Text(
                            'No activity yet...',
                            style: TextStyle(color: Colors.grey[400]),
                          ),
                        )
                            : ListView.builder(
                          itemCount: _logMessages.length,
                          itemBuilder: (context, index) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: index.isEven ? Colors.transparent : Colors.black.withOpacity(0.1),
                              ),
                              child: Text(
                                _logMessages[index],
                                style: TextStyle(
                                  color: _getLogColor(_logMessages[index]),
                                  fontSize: 12,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpeechResultCard(SpeechResult result) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: GcbAppTheme.surfaceLight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    result.detectedLanguage.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${(result.confidence * 100).toInt()}%',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTimestamp(result.timestamp),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Original text
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                result.originalText,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const SizedBox(height: 8),

            // Translations
            ...result.translations.entries
                .where((entry) => entry.key != result.detectedLanguage && entry.value.isNotEmpty)
                .map((entry) {
              final languageNames = {
                'en': 'English',
                'vi': 'Vietnamese',
                'zh': 'Chinese',
                'ja': 'Japanese',
                'ko': 'Korean',
              };

              return Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      languageNames[entry.key] ?? entry.key.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton() {
    return Consumer<IntegratedMeetingService>(
      builder: (context, service, child) {
        if (service.isInMeeting) {
          return FloatingActionButton.extended(
            onPressed: _stopWorkflow,
            backgroundColor: Colors.red,
            icon: const Icon(Icons.stop),
            label: const Text('Stop Workflow'),
          );
        } else {
          return FloatingActionButton.extended(
            onPressed: _startWorkflow,
            backgroundColor: Colors.green,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Start Workflow'),
          );
        }
      },
    );
  }

  Future<void> _startWorkflow() async {
    try {
      _addLog('🚀 Starting complete workflow...');

      final success = await _integratedService.startCompleteWorkflow(
        meetingId: _meetingIdController.text.trim(),
        displayName: _userNameController.text.trim(),
        targetLanguage: _selectedLanguage,
      );

      if (success) {
        _addLog('✅ Workflow started - Ready for live translation!');
        _showSnackBar('✅ Workflow started successfully!', Colors.green);
      } else {
        _addLog('❌ Failed to start workflow');
        _showSnackBar('❌ Failed to start workflow', Colors.red);
      }
    } catch (e) {
      _addLog('❌ Error: $e');
      _showSnackBar('❌ Error: $e', Colors.red);
    }
  }

  Future<void> _stopWorkflow() async {
    try {
      _addLog('🛑 Stopping workflow...');
      await _integratedService.stopCompleteWorkflow();
      _addLog('✅ Workflow stopped');
      _showSnackBar('✅ Workflow stopped', Colors.orange);
    } catch (e) {
      _addLog('❌ Error stopping: $e');
      _showSnackBar('❌ Error stopping: $e', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  Color _getLogColor(String message) {
    if (message.contains('❌') || message.contains('Error')) {
      return Colors.red;
    } else if (message.contains('⚠️') || message.contains('Warning')) {
      return Colors.orange;
    } else if (message.contains('✅') || message.contains('Success')) {
      return Colors.green;
    } else if (message.contains('🎤') || message.contains('Audio')) {
      return Colors.purple;
    } else if (message.contains('🗣️') || message.contains('Speech')) {
      return Colors.cyan;
    } else if (message.contains('🌐') || message.contains('Translation')) {
      return Colors.amber;
    } else if (message.contains('🚀') || message.contains('Starting')) {
      return Colors.lightBlue;
    } else if (message.contains('🛑') || message.contains('Stopping')) {
      return Colors.orange;
    } else {
      return Colors.white;
    }
  }

  @override
  void dispose() {
    _meetingIdController.dispose();
    _userNameController.dispose();
    if (_isInitialized) {
      _integratedService.dispose();
    }
    super.dispose();
  }
}