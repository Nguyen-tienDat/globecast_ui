// lib/screens/meeting/widgets/participants_panel.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:globecast_ui/theme/app_theme.dart';
import '../../../services/webrtc_mesh_meeting_service.dart';

class ParticipantsPanel extends StatelessWidget {
  const ParticipantsPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WebRTCMeshMeetingService>(
      builder: (context, webrtcService, child) {
        final participants = webrtcService.participants;

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
                      'Participants (${participants.length})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    IconButton(
                      onPressed: () {},
                      icon: const Icon(
                        Icons.more_horiz,
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
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: participants.length,
                  itemBuilder: (context, index) {
                    final participant = participants[index];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: GcbAppTheme.surfaceLight,
                        child: Text(
                          participant.name.isNotEmpty ? participant.name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: GcbAppTheme.textPrimary,
                          ),
                        ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              participant.name,
                              style: Theme.of(context).textTheme.bodyLarge,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (participant.isHost)
                            Container(
                              margin: const EdgeInsets.only(left: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: GcbAppTheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                'Host',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: GcbAppTheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Row(
                        children: [
                          if (!participant.isAudioEnabled)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.mic_off,
                                  color: Colors.red,
                                  size: 12,
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
                          else
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.mic,
                                  color: Colors.green,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Audio On',
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.more_vert,
                          color: GcbAppTheme.textSecondary,
                        ),
                        onPressed: () => _showParticipantOptions(context, participant),
                      ),
                    );
                  },
                ),
              ),

              // Invite button
              Container(
                padding: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Invite feature will be implemented soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                  icon: const Icon(
                    Icons.person_add,
                    size: 20,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Invite Participants',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: Colors.white,
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
              ),
            ],
          ),
        );
      },
    );
  }

  void _showParticipantOptions(BuildContext context, MeshParticipant participant) {
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
                ListTile(
                  leading: const Icon(Icons.record_voice_over),
                  title: const Text('Make Moderator'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Moderator feature will be implemented soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.mic),
                  title: const Text('Allow to Unmute'),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Audio control feature will be implemented soon'),
                        duration: Duration(seconds: 2),
                      ),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Remove participant feature will be implemented soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}