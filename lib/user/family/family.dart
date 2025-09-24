import 'package:flutter/material.dart';

import 'family_add_screen.dart';
import 'family_edit_screen.dart';
import 'family_scanner_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({Key? key}) : super(key: key);

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, String>> members = [
    {
      'name': 'John Doe',
      'relation': 'Father',
      'phone': '123-456-7890',
      'imageUrl': 'https://example.com/john.jpg'
    },
    {
      'name': 'Jane Doe',
      'relation': 'Mother',
      'phone': '098-765-4321',
      'imageUrl': 'https://example.com/jane.jpg'
    },
    {
      'name': 'Alice Doe',
      'relation': 'Sister',
      'phone': '555-555-5555',
      'imageUrl': 'https://example.com/alice.jpg'
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Family', style: TextStyle(color: Colors.white)),
      ),
      body: Container(
        color: Colors.lightBlue[100],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'search',
                  filled: true,
                  fillColor: Colors.grey[200],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (value) {
                  setState(() {});
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: NetworkImage(member['imageUrl']!),
                    ),
                    title: Text('${member['name']}'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('relation: ${member['relation']}'),
                        Text('phone: ${member['phone']}'),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () async {
                            final updatedMember = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditScreen(member: member),
                              ),
                            );
                            if (updatedMember != null) {
                              setState(() {
                                members[index] = updatedMember;
                              });
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () {
                            setState(() {
                              members.removeAt(index);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  FloatingActionButton(
                    onPressed: () async {
                      final newMember = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AddScreen()),
                      );
                      if (newMember != null) {
                        setState(() {
                          members.add(newMember);
                        });
                      }
                    },
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.add),
                  ),
                  FloatingActionButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const ScannerScreen(members: [])),
                      );
                      if (result != null && result['matchFound']) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Match found: ${result['memberName']}')),
                        );
                      }
                    },
                    backgroundColor: Colors.orange,
                    child: const Icon(Icons.camera_alt),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}