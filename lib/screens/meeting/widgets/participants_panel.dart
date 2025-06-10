// lib/screens/meeting/widgets/participants_panel.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';

// FIXED: Import correct models and service
import '../../../models/meeting_models.dart';
import '../../../services/sfu_server/sfu_meeting_service.dart';
import '../controller.dart';

class ParticipantsPanel extends StatelessWidget {
  const ParticipantsPanel({super.key});

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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Participants (${controller.participants.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    controller.toggleParticipantsList(); // Close participants panel
                  },
                  icon: const Icon(
                    Icons.close,
                    color: GcbAppTheme.textSecondary,
                  ),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 32,
                    minHeight: 32,
                  ),
                ),
              ],
            ),
          ),

          // Participants list
          Expanded(
            child: controller.participants.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 64,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No participants yet',
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: controller.participants.length,
              itemBuilder: (context, index) {
                final participant = controller.participants[index];
                return Card(
                  color: GcbAppTheme.surfaceLight,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: participant.isHost
                              ? Colors.amber.withOpacity(0.3)
                              : Colors.blue.withOpacity(0.3),
                          backgroundImage: participant.avatarUrl != null
                              ? NetworkImage(participant.avatarUrl!)
                              : null,
                          child: participant.avatarUrl == null
                              ? Text(
                            participant.name.isNotEmpty
                                ? participant.name[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: participant.isHost
                                  ? Colors.amber[700]
                                  : Colors.blue[700],
                            ),
                          )
                              : null,
                        ),
                        // Speaking indicator
                        if (participant.isSpeaking)
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green,
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(
                            participant.name,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: participant.isHost
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (participant.isHost)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.amber.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                  size: 12,
                                ),
                                const SizedBox(width: 2),
                                Text(
                                  'Host',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.amber,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    subtitle: Wrap(
                      spacing: 8,
                      children: [
                        // Speaking status
                        if (participant.isSpeaking)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.graphic_eq,
                                color: Colors.green,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Speaking',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          )
                        // Muted status
                        else if (participant.isMuted)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.mic_off,
                                color: Colors.red,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Muted',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.red,
                                ),
                              ),
                            ],
                          )
                        // Unmuted status
                        else
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.mic,
                                color: Colors.grey,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Unmuted',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),

                        // Hand raised status
                        if (participant.isHandRaised)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.back_hand,
                                color: Colors.orange,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Hand raised',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),

                        // Screen sharing status
                        if (participant.isScreenSharing)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.screen_share,
                                color: Colors.blue,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Sharing screen',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    trailing: controller.isHost && !participant.name.contains('(You)')
                        ? IconButton(
                      icon: const Icon(
                        Icons.more_vert,
                        color: GcbAppTheme.textSecondary,
                      ),
                      onPressed: () => _showParticipantOptions(context, participant),
                    )
                        : null,
                  ),
                );
              },
            ),
          ),

          // Invite button (only for host)
          if (controller.isHost)
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      _showInviteDialog(context, controller);
                    },
                    icon: const Icon(
                      Icons.person_add,
                      size: 20,
                      color: Colors.white,
                    ),
                    label: const Text(
                      'Invite Participants',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: GcbAppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Meeting ID: ${controller.meetingCode}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.grey[400],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showParticipantOptions(BuildContext context, ParticipantModel participant) {
    showModalBottomSheet(
      context: context,
      backgroundColor: GcbAppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    participant.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const Divider(color: GcbAppTheme.surfaceLight),

                // Options
                ListTile(
                  leading: const Icon(Icons.record_voice_over, color: Colors.blue),
                  title: const Text('Make Moderator', style: TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Implement make moderator
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Feature coming soon!')),
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    participant.isMuted ? Icons.mic : Icons.mic_off,
                    color: Colors.orange,
                  ),
                  title: Text(
                    participant.isMuted ? 'Ask to Unmute' : 'Mute Participant',
                    style: const TextStyle(color: Colors.white),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Implement mute/unmute participant
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Feature coming soon!')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.block,
                    color: Colors.red,
                  ),
                  title: const Text(
                    'Remove From Meeting',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _showRemoveConfirmation(context, participant);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRemoveConfirmation(BuildContext context, ParticipantModel participant) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        title: const Text(
          'Remove Participant',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to remove ${participant.name} from the meeting?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.blue)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement remove participant
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Feature coming soon!')),
              );
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(BuildContext context, MeetingController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: GcbAppTheme.surface,
        title: const Text(
          'Invite Participants',
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Share this meeting ID with others:',
              style: TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: GcbAppTheme.surfaceLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      controller.meetingCode,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      // TODO: Copy to clipboard
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Meeting ID copied!')),
                      );
                    },
                    icon: const Icon(Icons.copy, color: Colors.blue),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}