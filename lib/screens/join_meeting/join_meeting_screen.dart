// lib/screens/join_meeting/join_meeting_screen.dart - Updated with Language Flow
import 'package:flutter/material.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import 'package:provider/provider.dart';
import '../../router/app_router.dart';
import '../../services/webrtc_mesh_meeting_service.dart';
import '../language_selection/language_selection_screen.dart';

class JoinMeetingScreen extends StatefulWidget {
  const JoinMeetingScreen({super.key});

  @override
  State<JoinMeetingScreen> createState() => _JoinMeetingScreenState();
}

class _JoinMeetingScreenState extends State<JoinMeetingScreen>
    with TickerProviderStateMixin {

  final _formKey = GlobalKey<FormState>();
  final _meetingCodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  bool _isLoading = false;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _animationController.forward();
  }

  void _setupAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.8, curve: Curves.easeOut),
    ));

    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
    ));
  }

  @override
  void dispose() {
    _meetingCodeController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GcbAppTheme.background,
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _animationController,
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
        // Header với back button
        _buildHeader(),

        // Main content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),

                  // Welcome section
                  _buildWelcomeSection(),

                  const SizedBox(height: 32),

                  // Meeting code input
                  _buildMeetingCodeInput(),

                  const SizedBox(height: 20),

                  // Name input
                  _buildNameInput(),

                  const SizedBox(height: 16),

                  // Advanced options
                  _buildAdvancedSection(),

                  const SizedBox(height: 32),

                  // Language explanation
                  _buildLanguageExplanation(),

                  const SizedBox(height: 40),
                ],
              ),
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          const Expanded(
            child: Text(
              'Join Meeting',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 48), // Balance the back button
        ],
      ),
    );
  }

  Widget _buildWelcomeSection() {
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
          // Icon
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: GcbAppTheme.primary.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.meeting_room,
              color: GcbAppTheme.primary,
              size: 30,
            ),
          ),

          const SizedBox(height: 16),

          // Title
          Text(
            'Join Global Meeting',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // Description
          Text(
            'Enter meeting details and we\'ll help you set up real-time translation',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey[400],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildMeetingCodeInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Meeting Code',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        TextFormField(
          controller: _meetingCodeController,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            hintText: 'Enter meeting code (e.g., GCM-123-456)',
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: Icon(Icons.numbers, color: Colors.grey[400]),
            filled: true,
            fillColor: GcbAppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: GcbAppTheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a meeting code';
            }
            if (value.trim().length < 3) {
              return 'Meeting code is too short';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your Name',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),

        TextFormField(
          controller: _nameController,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Enter your display name',
            hintStyle: TextStyle(color: Colors.grey[500]),
            prefixIcon: Icon(Icons.person_outline, color: Colors.grey[400]),
            filled: true,
            fillColor: GcbAppTheme.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: GcbAppTheme.primary, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your name';
            }
            if (value.trim().length < 2) {
              return 'Name must be at least 2 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAdvancedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _showAdvanced = !_showAdvanced;
            });
          },
          child: Row(
            children: [
              Icon(
                _showAdvanced ? Icons.expand_less : Icons.expand_more,
                color: GcbAppTheme.primary,
              ),
              const SizedBox(width: 8),
              const Text(
                'Advanced Options',
                style: TextStyle(
                  color: GcbAppTheme.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _showAdvanced ? null : 0,
          child: _showAdvanced ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // Password field
              const Text(
                'Meeting Password (Optional)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              TextFormField(
                controller: _passwordController,
                obscureText: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Enter password if required',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[400]),
                  filled: true,
                  fillColor: GcbAppTheme.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: GcbAppTheme.primary, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                ),
              ),
            ],
          ) : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildLanguageExplanation() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.translate,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Next Step: Choose Your Language',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            'After joining, you\'ll select your preferred subtitle language. Everyone can speak their native language while you see subtitles in your chosen language.',
            style: TextStyle(
              color: Colors.orange.withOpacity(0.9),
              fontSize: 14,
              height: 1.4,
            ),
          ),

          const SizedBox(height: 12),

          // Example languages
          Wrap(
            spacing: 8,
            children: [
              _buildLanguageChip('🇺🇸 English'),
              _buildLanguageChip('🇻🇳 Tiếng Việt'),
              _buildLanguageChip('🇫🇷 Français'),
              _buildLanguageChip('🇪🇸 Español'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.orange,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
      // Progress indicator
      Row(
      children: [
      Container(
      width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: GcbAppTheme.primary,
          shape: BoxShape.circle,
        ),
      ),
      Expanded(
        child: Container(
          height: 2,
          color: Colors.grey[700],
          margin: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.grey[700],
          shape: BoxShape.circle,
        ),
      ),
      Expanded(
        child: Container(
          height: 2,
          color: Colors.grey[700],
          margin: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: Colors.grey[700],
          shape: BoxShape.circle,
        ),
      ),
      ],
    ),
  }