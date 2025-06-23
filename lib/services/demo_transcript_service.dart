// lib/services/demo_transcript_service.dart - UPDATED WITH "datz" SPEAKER NAME
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/translation_models.dart';
import 'translation_service.dart';

class DemoTranscriptService {
  // Generate quick demo for immediate display (used when joining meeting)
  static Future<void> generateQuickDemo({
    required TranslationService translationService,
    required String userDisplayLanguage,
    required String currentUserId,
    String? customUserName,
  }) async {
    try {
      if (kDebugMode) {
        print('⚡ Generating quick demo for language: $userDisplayLanguage');
      }

      // Get the appropriate greeting based on user's language
      final greetingData = _getGreetingForLanguage(userDisplayLanguage);

      if (kDebugMode) {
        print('🎯 Demo text for $userDisplayLanguage: "${greetingData['text']}"');
      }

      // Generate the first transcript immediately (current user) - ALWAYS USE "datz"
      final transcriptId = await translationService.saveSpeechTranscription(
        speakerId: currentUserId,
        speakerName: 'datz', // FORCE "datz" as speaker name regardless of customUserName
        originalText: greetingData['text']!,
        originalLanguage: userDisplayLanguage,
        isFinal: true,
        confidence: 0.98,
      );

      if (kDebugMode) {
        print('✅ Quick demo transcript created with ID: $transcriptId');
        print('📝 Text: "${greetingData['text']}"');
        print('🌍 Language: $userDisplayLanguage');
        print('👤 Speaker: datz (forced)');
      }

      // Generate a response from another participant after 3 seconds
      Future.delayed(const Duration(seconds: 3), () async {
        try {
          // Create different language response based on user's language
          String responseText;
          String responseLang;
          String speakerName;

          if (userDisplayLanguage == 'en') {
            responseText = 'Bonjour! Je suis Marie de France. Ravi de vous rencontrer!';
            responseLang = 'fr';
            speakerName = 'Marie (France)';
          } else if (userDisplayLanguage == 'fr') {
            responseText = 'Hello! I am John from USA. Nice to meet you!';
            responseLang = 'en';
            speakerName = 'John (USA)';
          } else if (userDisplayLanguage == 'vi') {
            responseText = 'こんにちは！日本のユキです。お会いできて嬉しいです！';
            responseLang = 'ja';
            speakerName = 'Yuki (Japan)';
          } else if (userDisplayLanguage == 'es') {
            responseText = 'Hola! Soy Carlos de México. Mucho gusto!';
            responseLang = 'es';
            speakerName = 'Carlos (Mexico)';
          } else if (userDisplayLanguage == 'de') {
            responseText = 'Guten Tag! Ich bin Hans aus Deutschland. Freut mich!';
            responseLang = 'de';
            speakerName = 'Hans (Germany)';
          } else if (userDisplayLanguage == 'zh') {
            responseText = '你好！我是李明，来自中国。很高兴认识你！';
            responseLang = 'zh';
            speakerName = 'Li Ming (China)';
          } else if (userDisplayLanguage == 'ja') {
            responseText = '안녕하세요! 한국의 김민준입니다. 만나서 반가워요!';
            responseLang = 'ko';
            speakerName = 'Kim Min-jun (Korea)';
          } else if (userDisplayLanguage == 'ko') {
            responseText = 'สวัสดีครับ! ผมเป็นคนไทย ยินดีที่ได้รู้จัก!';
            responseLang = 'th';
            speakerName = 'Somchai (Thailand)';
          } else if (userDisplayLanguage == 'ar') {
            responseText = 'مرحبا! أنا أحمد من مصر. سعيد بلقائك!';
            responseLang = 'ar';
            speakerName = 'Ahmed (Egypt)';
          } else {
            responseText = 'Hello! I am John from USA. Welcome to our meeting!';
            responseLang = 'en';
            speakerName = 'John (USA)';
          }

          await translationService.saveSpeechTranscription(
            speakerId: 'DEMO_RESPONSE_${DateTime.now().millisecondsSinceEpoch}',
            speakerName: speakerName,
            originalText: responseText,
            originalLanguage: responseLang,
            isFinal: true,
            confidence: 0.94,
          );

          if (kDebugMode) {
            print('⚡ Quick demo response generated: "$responseText" ($responseLang)');
          }
        } catch (e) {
          if (kDebugMode) {
            print('❌ Error generating demo response: $e');
          }
        }
      });

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error generating quick demo: $e');
      }
    }
  }

  // Generate cross-language demo (showing real-time translation)
  static Future<void> generateCrossLanguageDemo({
    required TranslationService translationService,
    required String userDisplayLanguage,
    required String meetingId,
    required String currentUserId,
  }) async {
    try {
      if (kDebugMode) {
        print('🌍 Generating cross-language demo for: $userDisplayLanguage');
      }

      // Demo scenario: Multiple people speaking different languages
      final demoScenarios = _getCrossLanguageScenarios(userDisplayLanguage);

      // Generate each transcript with realistic timing
      for (int i = 0; i < demoScenarios.length; i++) {
        await Future.delayed(Duration(milliseconds: 1000 + (i * 2500))); // 2.5 second intervals

        final scenario = demoScenarios[i];

        await translationService.saveSpeechTranscription(
          speakerId: scenario['speakerId']!,
          speakerName: scenario['speakerName']!,
          originalText: scenario['originalText']!,
          originalLanguage: scenario['originalLang']!,
          isFinal: true,
          confidence: 0.92 + (i * 0.015),
        );

        if (kDebugMode) {
          print('🌐 Generated cross-language transcript ${i + 1}: ${scenario['speakerName']} (${scenario['originalLang']})');
        }
      }

      if (kDebugMode) {
        print('✅ Cross-language demo generated successfully');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error generating cross-language demo: $e');
      }
    }
  }

  // Get appropriate greeting text for language - UPDATED FOR "datz"
  static Map<String, String> _getGreetingForLanguage(String languageCode) {
    switch (languageCode) {
      case 'vi':
        return {
          'text': 'Xin chào tôi là Đạt và tôi đến từ Việt Nam',
          'speaker': 'datz',
        };
      case 'en':
        return {
          'text': 'Xin chào tôi là Đạt và tôi đến từ Việt Nam',
          'speaker': 'datz',
        };
      case 'es':
        return {
          'text': 'Hola mi nombre es Dat y soy de Vietnam',
          'speaker': 'datz',
        };
      case 'fr':
        return {
          'text': 'Bonjour je m\'appelle Dat et je viens du Vietnam',
          'speaker': 'datz',
        };
      case 'zh':
        return {
          'text': '大家好，我叫Dat，来自越南',
          'speaker': 'datz',
        };
      case 'ja':
        return {
          'text': 'こんにちは、私の名前はDatで、ベトナム出身です',
          'speaker': 'datz',
        };
      case 'ko':
        return {
          'text': '안녕하세요 제 이름은 Dat이고 베트남에서 왔습니다',
          'speaker': 'datz',
        };
      case 'de':
        return {
          'text': 'Hallo, mein Name ist Dat und ich komme aus Vietnam',
          'speaker': 'datz',
        };
      case 'ru':
        return {
          'text': 'Привет, меня зовут Дат, я из Вьетнама',
          'speaker': 'datz',
        };
      case 'ar':
        return {
          'text': 'مرحبا اسمي دات وأنا من فيتنام',
          'speaker': 'datz',
        };
      default:
        return {
          'text': 'Xin chào tôi là Đạt và tôi đến từ Việt Nam',
          'speaker': 'datz',
        };
    }
  }

  // Get cross-language scenarios based on user's language
  static List<Map<String, String>> _getCrossLanguageScenarios(String userDisplayLanguage) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    // Base scenarios - different for each language to create variety
    switch (userDisplayLanguage) {
      case 'fr':
        return [
          {
            'speakerName': 'Ahmed (Maroc)',
            'originalText': 'مرحبا بكم جميعا في هذا الاجتماع الدولي',
            'originalLang': 'ar',
            'speakerId': 'DEMO_AHMED_$timestamp',
          },
          {
            'speakerName': 'Elena (España)',
            'originalText': 'Gracias Ahmed, creo que este proyecto necesitará más tiempo',
            'originalLang': 'es',
            'speakerId': 'DEMO_ELENA_${timestamp + 1}',
          },
          {
            'speakerName': 'Hans (Deutschland)',
            'originalText': 'Ich stimme Elena zu. Wir brauchen mindestens vier Monate',
            'originalLang': 'de',
            'speakerId': 'DEMO_HANS_${timestamp + 2}',
          },
        ];

      case 'en':
        return [
          {
            'speakerName': 'Marie (France)',
            'originalText': 'Merci de nous accueillir dans cette réunion importante',
            'originalLang': 'fr',
            'speakerId': 'DEMO_MARIE_$timestamp',
          },
          {
            'speakerName': 'Hiroshi (Japan)',
            'originalText': 'この会議は非常に重要ですね。良いアイデアを共有しましょう',
            'originalLang': 'ja',
            'speakerId': 'DEMO_HIROSHI_${timestamp + 1}',
          },
          {
            'speakerName': 'Carlos (Mexico)',
            'originalText': 'Estoy de acuerdo, esta colaboración será muy beneficiosa',
            'originalLang': 'es',
            'speakerId': 'DEMO_CARLOS_${timestamp + 2}',
          },
        ];

      case 'vi':
        return [
          {
            'speakerName': 'Lucy (Australia)',
            'originalText': 'G\'day everyone! Excited to work with such an international team',
            'originalLang': 'en',
            'speakerId': 'DEMO_LUCY_$timestamp',
          },
          {
            'speakerName': 'Pierre (Canada)',
            'originalText': 'Bonjour à tous! Cette collaboration internationale est fantastique',
            'originalLang': 'fr',
            'speakerId': 'DEMO_PIERRE_${timestamp + 1}',
          },
          {
            'speakerName': 'Min-jun (Korea)',
            'originalText': '안녕하세요! 이런 국제적인 협업이 정말 기대됩니다',
            'originalLang': 'ko',
            'speakerId': 'DEMO_MINJUN_${timestamp + 2}',
          },
        ];

      case 'es':
        return [
          {
            'speakerName': 'Giuseppe (Italia)',
            'originalText': 'Ciao a tutti! Sono molto felice di partecipare a questo progetto',
            'originalLang': 'it',
            'speakerId': 'DEMO_GIUSEPPE_$timestamp',
          },
          {
            'speakerName': 'Olga (Russia)',
            'originalText': 'Привет всем! Это отличная возможность для сотрудничества',
            'originalLang': 'ru',
            'speakerId': 'DEMO_OLGA_${timestamp + 1}',
          },
          {
            'speakerName': 'Chen (China)',
            'originalText': '大家好！很高兴参加这个国际会议',
            'originalLang': 'zh',
            'speakerId': 'DEMO_CHEN_${timestamp + 2}',
          },
        ];

      default:
        return [
          {
            'speakerName': 'Anna (Sweden)',
            'originalText': 'Hej alla! Det här är en fantastisk möjlighet för samarbete',
            'originalLang': 'sv',
            'speakerId': 'DEMO_ANNA_$timestamp',
          },
          {
            'speakerName': 'João (Brazil)',
            'originalText': 'Olá pessoal! Muito animado para trabalhar juntos',
            'originalLang': 'pt',
            'speakerId': 'DEMO_JOAO_${timestamp + 1}',
          },
          {
            'speakerName': 'Fatima (UAE)',
            'originalText': 'أهلا وسهلا بالجميع، سعيدة بهذا التعاون الدولي',
            'originalLang': 'ar',
            'speakerId': 'DEMO_FATIMA_${timestamp + 2}',
          },
        ];
    }
  }

  // Check if demo should be generated (always generate for better demo experience)
  static bool shouldGenerateDemo(String meetingId) {
    // Generate demo for ALL meetings to ensure consistent experience
    return true;
  }

  // Generate realistic typing demo (shows partial -> final transcripts)
  static Future<void> generateTypingDemo({
    required TranslationService translationService,
    required String userDisplayLanguage,
    required String currentUserId,
  }) async {
    try {
      final greetingData = _getGreetingForLanguage(userDisplayLanguage);
      final fullText = greetingData['text']!;

      // Simulate typing effect by sending partial transcripts
      final words = fullText.split(' ');
      String partialText = '';

      for (int i = 0; i < words.length; i++) {
        partialText += (i == 0 ? '' : ' ') + words[i];

        await translationService.saveSpeechTranscription(
          speakerId: currentUserId,
          speakerName: 'datz', // ALWAYS use "datz"
          originalText: partialText,
          originalLanguage: userDisplayLanguage,
          isFinal: i == words.length - 1, // Only final on last word
          confidence: 0.85 + (i * 0.02),
        );

        await Future.delayed(const Duration(milliseconds: 300)); // Typing speed
      }

      if (kDebugMode) {
        print('⌨️ Typing demo completed: "$fullText"');
      }

    } catch (e) {
      if (kDebugMode) {
        print('❌ Error generating typing demo: $e');
      }
    }
  }
}