// lib/careTaker/user_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UserDetailScreen extends StatelessWidget {
  final String userUid;
  final Map<String, dynamic> userData;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;
  final VoidCallback? onConfirmUnbind;

  const UserDetailScreen({
    super.key,
    required this.userUid,
    required this.userData,
    this.onAccept,
    this.onReject,
    this.onConfirmUnbind,
  });

  @override
  Widget build(BuildContext context) {
    final isConnectionRequest = onAccept != null && onReject != null;
    final isUnbindRequest = onConfirmUnbind != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(userData['fullName'] ?? 'User'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent.withOpacity(0.1), Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: NetworkImage(
                    userData['profileImageUrl'] ?? '',
                  ),
                  child: const Icon(Icons.person, size: 60, color: Colors.blueAccent),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Text(
                      userData['fullName'] ?? 'Unnamed',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    Text(
                      '@${userData['username'] ?? ''}',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow(Icons.info_outline, 'Bio', userData['bio'] ?? ''),
                      _buildInfoRow(Icons.location_city, 'City', userData['city'] ?? ''),
                      _buildInfoRow(Icons.phone, 'Phone', userData['phoneNo'] ?? ''),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final phone = userData['phoneNo'];
                        if (phone != null && phone.isNotEmpty) {
                          final url = Uri.parse('tel:$phone');
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Could not launch phone app')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.phone, color: Colors.white),
                      label: const Text('Call', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                    ),
                  ),
                  if (isConnectionRequest) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onAccept,
                        icon: const Icon(Icons.check, color: Colors.white),
                        label: const Text('Accept', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onReject,
                        icon: const Icon(Icons.close, color: Colors.white),
                        label: const Text('Reject', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ),
                  ],
                  if (isUnbindRequest) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: onConfirmUnbind,
                        icon: const Icon(Icons.link_off, color: Colors.white),
                        label: const Text('Confirm Unbind', style: TextStyle(color: Colors.white)),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}