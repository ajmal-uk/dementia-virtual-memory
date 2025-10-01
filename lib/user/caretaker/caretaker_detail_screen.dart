// lib/user/caretaker/caretaker_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class CaretakerDetailScreen extends StatelessWidget {
  final String caretakerUid;
  final Map<String, dynamic> caretakerData;
  final VoidCallback onConnect;

  const CaretakerDetailScreen({
    super.key,
    required this.caretakerUid,
    required this.caretakerData,
    required this.onConnect,
  });

  Widget _buildNurseBadge() {
    return Positioned(
      top: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: const BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.local_hospital,
          size: 16,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNurse = caretakerData['caregiverType'] == 'nurse';
    return Scaffold(
      appBar: AppBar(
        title: Text(caretakerData['fullName'] ?? 'Caretaker'),
        backgroundColor: Colors.blueAccent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueAccent.withValues(alpha: 0.1), Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey[300],
                      backgroundImage: NetworkImage(
                        caretakerData['profileImageUrl'] ?? '',
                      ),
                      child: const Icon(Icons.person, size: 60, color: Colors.blueAccent),
                    ),
                    if (isNurse) _buildNurseBadge(),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Column(
                  children: [
                    Text(
                      caretakerData['fullName'] ?? 'Unnamed',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                    ),
                    Text(
                      '@${caretakerData['username'] ?? ''}',
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
                      _buildInfoRow(Icons.info_outline, 'Bio', caretakerData['bio'] ?? ''),
                      _buildInfoRow(Icons.location_city, 'City', caretakerData['city'] ?? ''),
                      _buildInfoRow(Icons.phone, 'Phone', caretakerData['phoneNo'] ?? ''),
                      if (isNurse) ...[
                        _buildInfoRow(Icons.work_history, 'Experience Years', '${caretakerData['experienceYears'] ?? 0} years'),
                        _buildInfoRow(Icons.description, 'Experience Bio', caretakerData['experienceBio'] ?? ''),
                        _buildInfoRow(Icons.school, 'Nursing Qualification', caretakerData['graduationOnNursing'] ?? ''),
                        if (caretakerData['graduationCertificateUrl']?.isNotEmpty ?? false)
                          _buildInfoRow(Icons.picture_as_pdf, 'Certificate', 'View Certificate'),
                      ] else
                        _buildInfoRow(Icons.family_restroom, 'Relation', caretakerData['relation'] ?? ''),
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
                        final phone = caretakerData['phoneNo'];
                        if (phone != null && phone.isNotEmpty) {
                          final url = Uri.parse('tel:$phone');
                          final can = await canLaunchUrl(url);
                          if (can) {
                            await launchUrl(url);
                          } else if (context.mounted) {
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
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onConnect,
                      icon: const Icon(Icons.link, color: Colors.white),
                      label: const Text('Connect', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
                    ),
                  ),
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