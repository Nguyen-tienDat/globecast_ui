// lib/screens/language_selection/language_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/whisper_service.dart';
import '../../theme/app_theme.dart';
import '../../router/app_router.dart';

class LanguageSelectionScreen extends StatefulWidget {
  final String meetingCode;
  final String userName;

  const LanguageSelectionScreen({
    super.key,
    required this.meetingCode,
    required this.userName,
  });

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen>
    with TickerProviderStateMixin {

  late AnimationController _mainAnimationController;
  late AnimationController _exampleAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;
  late Animation<double> _exampleAnimation;

  String? _selectedLanguage;
  bool _isLoading = false;

  // Enhanced language data with native names and flags
  final Map<String, LanguageOption> _languages = {
    'en': LanguageOption(
      code: 'en',
      name: 'English',
      nativeName: 'English',
      flag: '🇺🇸',
      color: const Color(0xFF1E88E5),
      exampleText: 'Hello everyone!',
    ),
    'vi': LanguageOption(
      code: 'vi',
      name: 'Vietnamese',
      nativeName: 'Tiếng Việt',
      flag: '🇻🇳',
      color: const Color(0xFFD32F2F),
      exampleText: 'Xin chào mọi người!',
    ),
    'fr': LanguageOption(
      code: 'fr',
      name: 'French',
      nativeName: 'Français',
      flag: '🇫🇷',
      color: const Color(0xFF1976D2),
      exampleText: 'Bonjour tout le monde!',
    ),
    'es': LanguageOption(
      code: 'es',
      name: 'Spanish',
      nativeName: 'Español',
      flag: '🇪🇸',
      color: const Color(0xFFFF8F00),
      exampleText: '¡Hola a todos!',
    ),
    'de': LanguageOption(
      code: 'de',
      name: 'German',
      nativeName: 'Deutsch',
      flag: '🇩🇪',
      color: const Color(0xFF424242),
      exampleText: 'Hallo zusammen!',
    ),
    'zh': LanguageOption(
      code: 'zh',
      name: 'Chinese',
      nativeName: '中文',
      flag: '🇨🇳',
      color: const Color(0xFFD32F2F),
      exampleText: '大家好！',
    ),
    'ja': LanguageOption(
      code: 'ja',
      name: 'Japanese',
      nativeName: '日本語',
      flag: '🇯🇵',
      color: const Color(0xFFE53935),
      exampleText: 'こんにちは皆さん！',
    ),
    'ko': LanguageOption(
      code: 'ko',
      name: 'Korean',
      nativeName: '한국어',
      flag: '🇰🇷',
      color: const Color(0xFF1565C0),
      exampleText: '안녕하세요 여러분!',
    ),
  };

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _startAnimations();
  }

  void _setupAnimations() {
    _mainAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _exampleAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _mainAnimationController,
      curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
    ));

    _exampleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _exampleAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  void _startAnimations() {
    _mainAnimationController.forward();
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        _exampleAnimationController.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _mainAnimationController.dispose();
    _exampleAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _mainAnimationController,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: _buildContent(),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Header
        _buildHeader(),

        // Main content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                // Explanation section
                _buildExplanationSection(),

                const SizedBox(height: 32),

                // Live example
                _buildLiveExample(),

                const SizedBox(height: 32),

                // Language selection
                _buildLanguageSelection(),

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),

        // Bottom action
        _buildBottomAction(),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Choose Your Language',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: GcbAppTheme.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: GcbAppTheme.primary, width: 1),
                      ),
                      child: Text(
                        'Meeting: ${widget.meetingCode}',
                        style: const TextStyle(
                          color: GcbAppTheme.primary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48), // Balance the back button
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExplanationSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            GcbAppTheme.primary.withOpacity(0.1),
            GcbAppTheme.secondary.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: GcbAppTheme.primary.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Main icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: GcbAppTheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
              border: Border.all(color: GcbAppTheme.primary, width: 2),
            ),
            child: const Icon(
              Icons.translate,
              color: GcbAppTheme.primary,
              size: 40,
            ),
          ),

          const SizedBox(height: 20),

          // Title
          Text(
            'Magic Translation Experience',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 16),

          // Description
          Text(
            'Everyone speaks their native language.\nYou see everything in your chosen language.\nAI handles the translation automatically.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Colors.grey[300],
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 20),

          // Features
          _buildFeatureRow(Icons.mic, 'Speak your language naturally'),
          const SizedBox(height: 8),
          _buildFeatureRow(Icons.visibility, 'See subtitles in your language'),
          const SizedBox(height: 8),
          _buildFeatureRow(Icons.auto_awesome, 'AI translates everything instantly'),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, color: GcbAppTheme.primary, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLiveExample() {
    final languages = ['vi', 'en', 'fr'];
    final speakers = ['Alice (🇻🇳)', 'Bob (🇺🇸)', 'Claire (🇫🇷)'];
    final originalTexts = [
      'Xin chào mọi người!',
      'Hello everyone!',
      'Bonjour tout le monde!'
    ];

    return AnimatedBuilder(
      animation: _exampleAnimation,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.play_circle_filled, color: Colors.green, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Live Demo: 3 People, 3 Languages',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Show what each person sees based on selected language
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                _buildExampleMessage(
                  speaker: speakers[i],
                  originalText: originalTexts[i],
                  displayLanguage: _selectedLanguage ?? 'en',
                  isHighlighted: _selectedLanguage == languages[i],
                  animationValue: _exampleAnimation.value,
                ),
              ],

              const SizedBox(height: 16),

              // Explanation for selected language
              if (_selectedLanguage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: GcbAppTheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: GcbAppTheme.primary.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Text(
                        _languages[_selectedLanguage]?.flag ?? '🌍',
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'You will see all subtitles in ${_languages[_selectedLanguage]?.nativeName}',
                          style: const TextStyle(
                            color: GcbAppTheme.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildExampleMessage({
    required String speaker,
    required String originalText,
    required String displayLanguage,
    required bool isHighlighted,
    required double animationValue,
  }) {
    // Simulate translation for demo
    String translatedText = originalText;
    if (displayLanguage == 'vi') {
      translatedText = originalText == 'Hello everyone!' ? 'Xin chào mọi người!' :
      originalText == 'Bonjour tout le monde!' ? 'Xin chào mọi người!' : originalText;
    } else if (displayLanguage == 'en') {
      translatedText = originalText == 'Xin chào mọi người!' ? 'Hello everyone!' :
      originalText == 'Bonjour tout le monde!' ? 'Hello everyone!' : originalText;
    } else if (displayLanguage == 'fr') {
      translatedText = originalText == 'Xin chào mọi người!' ? 'Bonjour tout le monde!' :
      originalText == 'Hello everyone!' ? 'Bonjour tout le monde!' : originalText;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isHighlighted
            ? GcbAppTheme.primary.withOpacity(0.3)
            : Colors.grey[800],
        borderRadius: BorderRadius.circular(8),
        border: isHighlighted
            ? Border.all(color: GcbAppTheme.primary, width: 2)
            : Border.all(color: Colors.grey[700]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            speaker,
            style: TextStyle(
              color: isHighlighted ? GcbAppTheme.primary : Colors.grey[400],
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            translatedText,
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Your Subtitle Language',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Choose the language you want to see subtitles in',
          style: TextStyle(
            color: Colors.grey[400],
            fontSize: 14,
          ),
        ),

        const SizedBox(height: 20),

        // Language grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _languages.length,
          itemBuilder: (context, index) {
            final language = _languages.values.elementAt(index);
            final isSelected = _selectedLanguage == language.code;

            return _buildLanguageCard(language, isSelected);
          },
        ),
      ],
    );
  }

  Widget _buildLanguageCard(LanguageOption language, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedLanguage = language.code;
        });
        HapticFeedback.lightImpact();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? language.color.withOpacity(0.2)
              : GcbAppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? language.color : Colors.white.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: language.color.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 1,
            ),
          ] : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              children: [
                Text(
                  language.flag,
                  style: const TextStyle(fontSize: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.nativeName,
                        style: TextStyle(
                          color: isSelected ? language.color : Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        language.name,
                        style: TextStyle(
                          color: isSelected
                              ? language.color.withOpacity(0.8)
                              : Colors.grey[400],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: isSelected ? language.color : Colors.transparent,
                    border: Border.all(
                      color: isSelected ? language.color : Colors.grey[600]!,
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: isSelected
                      ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 12,
                  )
                      : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Info message
          if (_selectedLanguage == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please select a language to continue',
                      style: TextStyle(
                        color: Colors.orange,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          if (_selectedLanguage != null) ...[
            // Selected language preview
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: GcbAppTheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: GcbAppTheme.primary.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Text(
                    _languages[_selectedLanguage]?.flag ?? '🌍',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You selected: ${_languages[_selectedLanguage]?.nativeName}',
                          style: const TextStyle(
                            color: GcbAppTheme.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          'All subtitles will appear in ${_languages[_selectedLanguage]?.nativeName}',
                          style: TextStyle(
                            color: GcbAppTheme.primary.withOpacity(0.8),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Join button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedLanguage != null && !_isLoading
                  ? _joinMeeting
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: GcbAppTheme.primary,
                disabledBackgroundColor: Colors.grey[800],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: _selectedLanguage != null ? 4 : 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.meeting_room, color: Colors.white),
                  const SizedBox(width: 12),
                  Text(
                    'Join Meeting as ${widget.userName}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _joinMeeting() async {
    if (_selectedLanguage == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // Save language preference
      final whisperService = Provider.of<WhisperService>(context, listen: false);
      // Set the user's preferred display language
      // This will be used when joining the meeting

      // Navigate to meeting with language preference
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.meeting,
            (route) => false,
        arguments: {
          'code': widget.meetingCode,
          'userName': widget.userName,
          'displayLanguage': _selectedLanguage,
        },
      );

    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to join meeting: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class LanguageOption {
  final String code;
  final String name;
  final String nativeName;
  final String flag;
  final Color color;
  final String exampleText;

  LanguageOption({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flag,
    required this.color,
    required this.exampleText,
  });
}