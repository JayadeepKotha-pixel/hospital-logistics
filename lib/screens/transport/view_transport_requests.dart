import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewTransportRequests extends StatefulWidget {
  const ViewTransportRequests({super.key});

  @override
  State<ViewTransportRequests> createState() => _ViewTransportRequestsState();
}

class _ViewTransportRequestsState extends State<ViewTransportRequests> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Check deadlines immediately when this screen is opened
    _checkDeadlines();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkDeadlines();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkDeadlines() async {
    final now = DateTime.now();
    final snapshot = await FirebaseFirestore.instance
        .collection('transport_requests')
        .where('status', isEqualTo: 'bidding')
        .get();

    for (var doc in snapshot.docs) {
      final data = doc.data();
      final deadlineTimestamp = data['bidding_deadline'] as Timestamp?;
      if (deadlineTimestamp == null) continue;
      final deadline = deadlineTimestamp.toDate();
      if (now.isAfter(deadline)) {
        await _closeBidding(doc.id);
      }
    }
  }

  Future<void> _closeBidding(String requestId) async {
    final requestRef = FirebaseFirestore.instance
        .collection('transport_requests')
        .doc(requestId);
    final requestSnap = await requestRef.get();

    if (!requestSnap.exists) return;

    final requestData = requestSnap.data() as Map<String, dynamic>? ?? {};
    final isEmergency = requestData['request_type'] == 'Emergency';
    final alreadyExtended = requestData['deadline_extended'] == true;

    final medicineRequestId = requestData['request_id'] as String? ?? requestId;

    final bidsSnapshot = await FirebaseFirestore.instance
        .collection('transport_bids')
        .where('request_id', isEqualTo: requestId)
        .where('status', isEqualTo: 'Pending')
        .get();

    // Emergency requests get one automatic 1.5 min extension if no bids arrived.
    if (bidsSnapshot.docs.isEmpty) {
      if (isEmergency && !alreadyExtended) {
          final newDeadline = DateTime.now().add(const Duration(seconds: 90));
          await requestRef.update({
            'bidding_deadline': Timestamp.fromDate(newDeadline),
            'deadline_extended': true,
          });
          return;
        }
      await requestRef.update({'status': 'Closed'});

      await FirebaseFirestore.instance
          .collection('medicine_requests')
          .doc(medicineRequestId)
          .update({
        'status': 'Closed',
      });

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

    await requestRef.update({'status': 'Closed'});

    // Update the original medicine request so the hospital can see the assigned transporter.
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

    await FirebaseFirestore.instance
        .collection('selected_transport')
        .doc(requestId)
        .set({
      'request_id': requestId,
      'transporter_id': best.data()['transporter_id'],
      'delivery_time': best.data()['delivery_time'],
      'cost': best.data()['bid_price'],
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Transport Requests")),

      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("transport_requests")
            .orderBy('timestamp', descending: true)
            .snapshots(),

        builder: (context, snapshot) {

          if (snapshot.hasError) {
            return Center(child: Text('Error loading requests: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(
              child: Text("No transport requests available"),
            );
          }

          return Column(
            children: [

              Expanded(
                child: ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final raw = doc.data() as Map<String, dynamic>? ?? {};

                    final status = raw['status'] as String? ?? '';
                    final deadlineTimestamp = raw['bidding_deadline'] as Timestamp?;
                    final now = DateTime.now();
                    final deadline = deadlineTimestamp?.toDate();
                    final biddingOpen = status == 'bidding' && deadline != null && now.isBefore(deadline);

                    if (status == 'bidding' && deadline != null && now.isAfter(deadline)) {
                      _checkDeadlines();
                    }

                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: ListTile(
                        title: Text(raw['item_name'] ?? ''),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Status: ${status.isEmpty ? 'unknown' : status}'),
                            Text('Pickup: ${raw['pickup_location'] ?? ''}'),
                            Text('Delivery: ${raw['delivery_location'] ?? ''}'),
                            Text('Quantity: ${raw['quantity'] ?? ''}'),
                            Text('Temperature: ${raw['temperature'] ?? ''}°C'),
                            Text('Required Delivery: ${raw['required_delivery_time'] ?? ''}'),
                            Text('Deadline: ${deadline != null ? deadline.toLocal().toString() : 'none'}'),
                          ],
                        ),
                        trailing: ElevatedButton(
                          child: Text(biddingOpen ? 'Bid' : 'Bidding Closed'),
                          onPressed: biddingOpen
                              ? () {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      final bidPriceController = TextEditingController();
                                      final bidDeliveryTimeController = TextEditingController();
                                      final vehicleTypeController = TextEditingController();
                                      final tempRangeController = TextEditingController();

                                      return AlertDialog(
                                        title: const Text('Enter Bid Details'),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextField(
                                              controller: bidPriceController,
                                              keyboardType: TextInputType.number,
                                              decoration: const InputDecoration(
                                                labelText: 'Bid Price',
                                                prefixText: '₹',
                                              ),
                                            ),
                                            TextField(
                                              controller: bidDeliveryTimeController,
                                              decoration: const InputDecoration(
                                                labelText: 'Delivery Time',
                                              ),
                                            ),
                                            TextField(
                                              controller: vehicleTypeController,
                                              decoration: const InputDecoration(
                                                labelText: 'Vehicle Type',
                                              ),
                                            ),
                                            TextField(
                                              controller: tempRangeController,
                                              decoration: const InputDecoration(
                                                labelText: 'Temperature Range',
                                              ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          TextButton(
                                            child: const Text('Cancel'),
                                            onPressed: () => Navigator.pop(context),
                                          ),
                                          ElevatedButton(
                                            child: const Text('Submit'),
                                            onPressed: () async {
                                              final userId = FirebaseAuth.instance.currentUser?.uid;
                                              final userDoc = userId != null
                                                  ? await FirebaseFirestore.instance.collection('users').doc(userId).get()
                                                  : null;

                                              await FirebaseFirestore.instance
                                                  .collection('transport_bids')
                                                  .add({
                                                'request_id': doc.id,
                                                'transporter_id': userId,
                                                'transporter_name': userDoc?.data()?['name'] ?? '',
                                                'bid_price': bidPriceController.text,
                                                'delivery_time': bidDeliveryTimeController.text,
                                                'vehicle_type': vehicleTypeController.text,
                                                'temperature_range': tempRangeController.text,
                                                'status': 'Pending',
                                                'timestamp': DateTime.now().toIso8601String(),
                                              });

                                              Navigator.pop(context);
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }
                              : null,
                        ),
                      ),
                    );
                  },
                ),
              ),

            ],
          );
        },
      ),
    );
  }
}
