
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:untitled/account_statement_screen.dart'; // Use the main AccountStatementScreen

class AccountSelectionScreen extends StatelessWidget {
  const AccountSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('اختر حساب لعرض الكشف')),
      body: user == null
          ? const Center(child: Text('المستخدم غير معرف'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('accounts').where('userId', isEqualTo: user.uid).orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('لا توجد حسابات'));
                }
                return ListView.builder(
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final accountDoc = snapshot.data!.docs[index];
                    final accountData = accountDoc.data() as Map<String, dynamic>;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        title: Text(accountData['name'] ?? 'بلا اسم'),
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => AccountStatementScreen(accountId: accountDoc.id, accountName: accountData['name'])));
                        },
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
