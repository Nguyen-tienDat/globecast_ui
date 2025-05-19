import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';

import '../controller.dart';

class LanguageSelectionPanel extends StatelessWidget {
  LanguageSelectionPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MeetingController>();

    return Container(
      decoration: const BoxDecoration(
        color: GcbAppTheme.surface,
        border: Border(
          left: BorderSide(
            color: GcbAppTheme.surfaceLight,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: GcbAppTheme.surfaceLight,
              border: Border(
                bottom: BorderSide(
                  color: GcbAppTheme.surface,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Language',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),

          // Language description
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Select the language you want to hear subtitles in:',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: GcbAppTheme.textSecondary,
              ),
            ),
          ),

          // Language options
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: _availableLanguages.length,
              itemBuilder: (context, index) {
                final language = _availableLanguages[index];
                final isSelected = controller.selectedLanguage == language.code;

                return ListTile(
                  title: Text(
                    language.displayName,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  leading: Text(
                    language.flag,
                    style: const TextStyle(fontSize: 24),
                  ),
                  trailing: isSelected
                      ? const Icon(
                    Icons.check,
                    color: GcbAppTheme.primary,
                    size: 20,
                  )
                      : null,
                  onTap: () => controller.setSelectedLanguage(language.code),
                  tileColor: isSelected ? GcbAppTheme.primary.withOpacity(0.1) : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                );
              },
            ),
          ),

          // Note about subtitles
          Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  color: Colors.blue,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Subtitles are generated in real-time and may not be 100% accurate.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.blue,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // List of available languages
  final List<_Language> _availableLanguages = [
    _Language(code: 'english', displayName: 'English', flag: '🇺🇸'),
    _Language(code: 'spanish', displayName: 'Spanish', flag: '🇪🇸'),
    _Language(code: 'french', displayName: 'French', flag: '🇫🇷'),
    _Language(code: 'german', displayName: 'German', flag: '🇩🇪'),
    _Language(code: 'chinese', displayName: 'Chinese', flag: '🇨🇳'),
    _Language(code: 'japanese', displayName: 'Japanese', flag: '🇯🇵'),
    _Language(code: 'korean', displayName: 'Korean', flag: '🇰🇷'),
    _Language(code: 'arabic', displayName: 'Arabic', flag: '🇸🇦'),
    _Language(code: 'russian', displayName: 'Russian', flag: '🇷🇺'),
  ];
}

class _Language {
  final String code;
  final String displayName;
  final String flag;

  _Language({
    required this.code,
    required this.displayName,
    required this.flag,
  });
}