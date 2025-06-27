// lib/screens/language/language_settings_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../theme/app_theme.dart';
import '../../models/translation_models.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  String _selectedSpeakingLanguage = 'vi';
  String _selectedDisplayLanguage = 'vi';
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _selectedSpeakingLanguage = prefs.getString('speaking_language') ?? 'vi';
        _selectedDisplayLanguage = prefs.getString('display_language') ?? 'vi';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _isSaving = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('speaking_language', _selectedSpeakingLanguage);
      await prefs.setString('display_language', _selectedDisplayLanguage);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Language preferences saved!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );

        // Return settings to previous screen
        Navigator.pop(context, {
          'speakingLanguage': _selectedSpeakingLanguage,
          'displayLanguage': _selectedDisplayLanguage,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: GcbAppTheme.background,
        appBar: AppBar(
          backgroundColor: GcbAppTheme.surface,
          title: const Text('Language Settings', style: TextStyle(color: Colors.white)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: GcbAppTheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      appBar: AppBar(
        backgroundColor: GcbAppTheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Language Settings',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Center(
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: GcbAppTheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.language,
                      size: 48,
                      color: GcbAppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Personal Language Preferences',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set your speaking and display languages for meetings',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Current Settings Preview
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  const Text(
                    'Current Settings',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              SupportedLanguages.getLanguageFlag(_selectedSpeakingLanguage),
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'I speak',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            Text(
                              SupportedLanguages.getLanguageName(_selectedSpeakingLanguage),
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.arrow_forward, color: Colors.blue, size: 24),
                      Expanded(
                        child: Column(
                          children: [
                            Text(
                              SupportedLanguages.getLanguageFlag(_selectedDisplayLanguage),
                              style: const TextStyle(fontSize: 32),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'I see everything in',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                            Text(
                              SupportedLanguages.getLanguageName(_selectedDisplayLanguage),
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Speaking Language Section
            _buildLanguageSection(
              title: '🎤 Speaking Language',
              subtitle: 'The language you will speak in meetings',
              selectedLanguage: _selectedSpeakingLanguage,
              onLanguageChanged: (language) {
                setState(() {
                  _selectedSpeakingLanguage = language;
                });
              },
            ),

            const SizedBox(height: 32),

            // Display Language Section
            _buildLanguageSection(
              title: '👁️ Display Language',
              subtitle: 'All conversations will be translated to this language for you',
              selectedLanguage: _selectedDisplayLanguage,
              onLanguageChanged: (language) {
                setState(() {
                  _selectedDisplayLanguage = language;
                });
              },
            ),

            const SizedBox(height: 32),

            // Info Section
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
                      Icon(Icons.info_outline, color: Colors.green, size: 20),
                      SizedBox(width: 12),
                      Text(
                        'How Personal Translation Works',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildInfoItem('🗣️ You speak in your chosen speaking language'),
                  _buildInfoItem('👂 You hear others in your chosen display language'),
                  _buildInfoItem('🌐 Everyone else hears you in their display language'),
                  _buildInfoItem('🤝 Natural multilingual conversations'),
                  _buildInfoItem('☁️ Powered by Google Cloud AI'),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: GcbAppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.save, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Save Language Preferences',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${SupportedLanguages.getLanguageFlag(_selectedSpeakingLanguage)} → ${SupportedLanguages.getLanguageFlag(_selectedDisplayLanguage)}',
                      style: const TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Test Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  _showTestDialog();
                },
                icon: const Icon(Icons.mic, size: 20),
                label: const Text('Test My Settings'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.orange,
                  side: const BorderSide(color: Colors.orange),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSection({
    required String title,
    required String subtitle,
    required String selectedLanguage,
    required Function(String) onLanguageChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 16),

        // Popular languages grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 3.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: _getPopularLanguages().length,
          itemBuilder: (context, index) {
            final langCode = _getPopularLanguages()[index];
            final isSelected = langCode == selectedLanguage;

            return InkWell(
              onTap: () => onLanguageChanged(langCode),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? GcbAppTheme.primary.withOpacity(0.2)
                      : GcbAppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected ? Border.all(
                    color: GcbAppTheme.primary,
                    width: 2,
                  ) : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      SupportedLanguages.getLanguageFlag(langCode),
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        SupportedLanguages.getLanguageName(langCode),
                        style: TextStyle(
                          color: isSelected ? GcbAppTheme.primary : Colors.white,
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.check_circle,
                        color: GcbAppTheme.primary,
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        // More languages button
        InkWell(
          onTap: () => _showAllLanguagesDialog(selectedLanguage, onLanguageChanged),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.grey[600]!,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.more_horiz,
                  color: Colors.grey[400],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'See all ${SupportedLanguages.getAllLanguageCodes().length} languages',
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.green[300],
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _getPopularLanguages() {
    return ['vi', 'en', 'zh', 'ja', 'ko', 'th', 'es', 'fr'];
  }

  void _showAllLanguagesDialog(String currentSelection, Function(String) onChanged) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Select Language',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: ListView.builder(
            itemCount: SupportedLanguages.getAllLanguageCodes().length,
            itemBuilder: (context, index) {
              final langCode = SupportedLanguages.getAllLanguageCodes()[index];
              final isSelected = langCode == currentSelection;

              return ListTile(
                leading: Text(
                  SupportedLanguages.getLanguageFlag(langCode),
                  style: const TextStyle(fontSize: 24),
                ),
                title: Text(
                  SupportedLanguages.getLanguageName(langCode),
                  style: TextStyle(
                    color: isSelected ? GcbAppTheme.primary : Colors.white,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                subtitle: Text(
                  SupportedLanguages.getNativeName(langCode),
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 12,
                  ),
                ),
                trailing: isSelected
                    ? const Icon(
                  Icons.check_circle,
                  color: GcbAppTheme.primary,
                )
                    : null,
                onTap: () {
                  onChanged(langCode);
                  Navigator.of(context).pop();
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _showTestDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mic, color: Colors.orange, size: 24),
            SizedBox(width: 12),
            Text('Test Language Settings', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your settings will work like this in meetings:',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        SupportedLanguages.getLanguageFlag(_selectedSpeakingLanguage),
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      const Text('You speak:', style: TextStyle(color: Colors.blue, fontSize: 12)),
                    ],
                  ),
                  Text(
                    '"Hello everyone" (${SupportedLanguages.getLanguageName(_selectedSpeakingLanguage)})',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  const Icon(Icons.arrow_downward, color: Colors.blue),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text(
                        SupportedLanguages.getLanguageFlag(_selectedDisplayLanguage),
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(width: 8),
                      const Text('Others see:', style: TextStyle(color: Colors.green, fontSize: 12)),
                    ],
                  ),
                  Text(
                    '"Hello everyone" → "Translated text"',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Got it!', style: TextStyle(color: GcbAppTheme.primary)),
          ),
        ],
      ),
    );
  }
}