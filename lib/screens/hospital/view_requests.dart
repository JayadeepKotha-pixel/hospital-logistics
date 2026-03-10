import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewHospitalRequests extends StatefulWidget {
  const ViewHospitalRequests({super.key});

  @override
  State<ViewHospitalRequests> createState() => _ViewHospitalRequestsState();
}

class _ViewHospitalRequestsState extends State<ViewHospitalRequests> {
  Future<void> _closeExpiredBidsForRequest(String medicineRequestId) async {
    final transportSnapshot = await FirebaseFirestore.instance
        .collection('transport_requests')
        .where('request_id', isEqualTo: medicineRequestId)
        .where('status', isEqualTo: 'bidding')
        .get();

    for (var trDoc in transportSnapshot.docs) {
      final trData = trDoc.data();
      final deadlineTimestamp = trData['bidding_deadline'] as Timestamp?;
      if (deadlineTimestamp == null) continue;

      final deadline = deadlineTimestamp.toDate();
      if (DateTime.now().isAfter(deadline)) {
        await _closeBiddingAndAssign(
          transportRequestId: trDoc.id,
          medicineRequestId: medicineRequestId,
        );
      }
    }
  }

  Future<void> _closeBiddingAndAssign({
    required String transportRequestId,
    required String medicineRequestId,
  }) async {
    final bidsSnapshot = await FirebaseFirestore.instance
        .collection('transport_bids')
        .where('request_id', isEqualTo: transportRequestId)
        .where('status', isEqualTo: 'Pending')
        .get();

    if (bidsSnapshot.docs.isEmpty) {
      await FirebaseFirestore.instance
          .collection('transport_requests')
          .doc(transportRequestId)
          .update({'status': 'Closed'});

      await FirebaseFirestore.instance
          .collection('medicine_requests')
          .doc(medicineRequestId)
          .update({'status': 'Closed'});

      return;
    }

    int parseHours(String value) {
      final match = RegExp(r"(\d+)").firstMatch(value);
      if (match == null) return 0;
      return int.tryParse(match.group(1) ?? '') ?? 0;
    }

    var best = bidsSnapshot.docs.first;
    var bestHours = parseHours(best.data()['delivery_time'] ?? '0');

    for (var bid in bidsSnapshot.docs) {
      final hours = parseHours(bid.data()['delivery_time'] ?? '0');
      if (hours < bestHours) {
        best = bid;
        bestHours = hours;
      }
    }

    await FirebaseFirestore.instance
        .collection('transport_bids')
        .doc(best.id)
        .update({'status': 'Selected'});

    await FirebaseFirestore.instance
        .collection('transport_requests')
        .doc(transportRequestId)
        .update({'status': 'Closed'});

    await FirebaseFirestore.instance
        .collection('medicine_requests')
        .doc(medicineRequestId)
        .update({
      'status': 'Transport Assigned',
      'transporter_id': best.data()['transporter_id'],
      'transporter_name': best.data()['transporter_name'] ?? '',
      'delivery_time': best.data()['delivery_time'],
      'transport_cost': best.data()['bid_price'],
    });
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('My Requests')),
      body: StreamBuilder<QuerySnapshot>(
        // Firestore requires a composite index for queries that filter by one field and
        // order by another (e.g., where('hospital_id') + orderBy('timestamp')).
        // To avoid needing an index, we only filter by hospital_id and sort locally.
        stream: FirebaseFirestore.instance
            .collection('medicine_requests')
            .where('hospital_id', isEqualTo: userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);

          // Sort by timestamp (descending) on the client to avoid needing a Firestore index.
          docs.sort((a, b) {
            final aTimestamp = (a.data() as Map<String, dynamic>? ?? {})['timestamp'];
            final bTimestamp = (b.data() as Map<String, dynamic>? ?? {})['timestamp'];

            DateTime aDate;
            DateTime bDate;

            if (aTimestamp is Timestamp) {
              aDate = aTimestamp.toDate();
            } else if (aTimestamp is DateTime) {
              aDate = aTimestamp;
            } else {
              aDate = DateTime.fromMillisecondsSinceEpoch(0);
            }

            if (bTimestamp is Timestamp) {
              bDate = bTimestamp.toDate();
            } else if (bTimestamp is DateTime) {
              bDate = bTimestamp;
            } else {
              bDate = DateTime.fromMillisecondsSinceEpoch(0);
            }

            return bDate.compareTo(aDate);
          });

          if (docs.isEmpty) {
            return const Center(child: Text('No requests found'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>? ?? {};
              final status = data['status'] as String? ?? '';

              // Ensure we close any expired bidding cycles for this request.
              if (status == 'Pending' || status == 'bidding') {
                _closeExpiredBidsForRequest(docs[index].id);
              }

              return Card(
                margin: const EdgeInsets.all(10),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Medicine: ${data['item_name'] ?? ''}'),
                      Text('Quantity: ${data['quantity'] ?? ''}'),
                      const SizedBox(height: 8),
                      Text('Status: ${status.isEmpty ? 'Unknown' : status}'),

                      if (status == 'Transport Assigned') ...[
                        const Divider(height: 20),
                        Text('Transporter: ${data['transporter_name'] ?? ''}'),
                        Text('Delivery Time: ${data['delivery_time'] ?? ''} hrs'),
                        Text('Transport Cost: ₹${data['transport_cost'] ?? ''}'),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
