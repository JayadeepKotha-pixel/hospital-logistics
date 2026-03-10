import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ViewRequests extends StatelessWidget {
  const ViewRequests({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(title: const Text("Medicine Requests")),

      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection("medicine_requests")
            .snapshots(),

        builder: (context, snapshot) {

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('No requests found'));
          }

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {

              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>? ?? {};
              final status = data['status'] as String? ?? '';

              return Card(
                child: ListTile(
                  title: Text(data["item_name"] ?? "Unknown"),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Shipment Type: ${data["shipment_type"] ?? ''}"),
                      Text("Quantity: ${data["quantity"] ?? ''} ${data["unit"] ?? ''}"),
                      Text("Delivery: ${data["delivery_time"] ?? ''}"),
                      Text("Temperature: ${data["temperature"] ?? ''}"),
                      Text("Location: ${data["delivery_location"] ?? ''}"),
                      const SizedBox(height: 8),
                      Text("Status: ${status.isEmpty ? 'Unknown' : status}"),

                      if (status == 'Transport Assigned') ...[
                        const Divider(height: 16),
                        Text('Transporter: ${data['transporter_name'] ?? ''}'),
                        Text('Delivery Time: ${data['delivery_time'] ?? ''} hrs'),
                        Text('Transport Cost: ₹${data['transport_cost'] ?? ''}'),
                      ],
                    ],
                  ),

                  trailing: Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        child: const Text("Accept"),
                        onPressed: () async {
                          String pickupLocation = "Distributor Warehouse";

                          await showDialog<void>(
                            context: context,
                            builder: (context) {
                              final pickupController = TextEditingController(text: pickupLocation);
                              String mode = "Distributor";

                              return AlertDialog(
                                title: const Text("Confirm Pickup"),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    DropdownButtonFormField(
                                      value: mode,
                                      items: const [
                                        DropdownMenuItem(value: "Distributor", child: Text("Distributor Warehouse")),
                                        DropdownMenuItem(value: "Manufacturer", child: Text("Manufacturer Location")),
                                      ],
                                      onChanged: (value) {
                                        mode = value!;
                                        pickupController.text = value == "Manufacturer"
                                            ? "Manufacturer Location"
                                            : "Distributor Warehouse";
                                      },
                                      decoration: const InputDecoration(labelText: "Source"),
                                    ),
                                    const SizedBox(height: 12),
                                    TextField(
                                      controller: pickupController,
                                      decoration: const InputDecoration(labelText: "Pickup Location"),
                                    ),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    child: const Text("Cancel"),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  ElevatedButton(
                                    child: const Text("Confirm"),
                                    onPressed: () {
                                      pickupLocation = pickupController.text;
                                      Navigator.pop(context);
                                    },
                                  ),
                                ],
                              );
                            },
                          );

                          // Update medicine request status
                          await FirebaseFirestore.instance
                              .collection("medicine_requests")
                              .doc(doc.id)
                              .update({
                            "status": "Accepted",
                          });

                          // Create transport request
                          final isEmergency = (data['request_type'] as String?) == 'Emergency';
                          final biddingSeconds = isEmergency ? 90 : 120;
                          final now = DateTime.now();
                          final deadline = now.add(Duration(seconds: biddingSeconds));

                          await FirebaseFirestore.instance
                              .collection("transport_requests")
                              .add({
                            "request_id": doc.id,
                            "distributor_id": FirebaseAuth.instance.currentUser?.uid,
                            "pickup_location": pickupLocation,
                            "delivery_location": data["delivery_location"],
                            "item_name": data["item_name"],
                            "quantity": data["quantity"],
                            "temperature": data["temperature"],
                            "required_delivery_time": data["delivery_time"],
                            "request_type": data["request_type"],
                            "bidding_start_time": Timestamp.fromDate(now),
                            "bidding_deadline": Timestamp.fromDate(deadline),
                            "deadline_extended": false,
                            "status": "bidding",
                            "timestamp": Timestamp.fromDate(now),
                          });
                        },
                      ),
                      ElevatedButton(
                        child: const Text("Reject"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                        ),
                        onPressed: () async {
                          await FirebaseFirestore.instance
                              .collection("medicine_requests")
                              .doc(doc.id)
                              .update({
                            "status": "Rejected",
                            "reason": "Medicine unavailable",
                          });
                        },
                      ),
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
