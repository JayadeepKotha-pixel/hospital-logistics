import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RequestMedicine extends StatefulWidget {
  const RequestMedicine({super.key});

  @override
  State<RequestMedicine> createState() => _RequestMedicineState();
}

class _RequestMedicineState extends State<RequestMedicine> {

  String shipmentType = "Medicine";

  final itemNameController = TextEditingController();
  final quantityController = TextEditingController();
  final unitController = TextEditingController();
  final weightController = TextEditingController();

  final pickupLocationController = TextEditingController();
  final deliveryLocationController = TextEditingController();
  final deliveryTimeController = TextEditingController();
  String requestType = "Normal";

  final temperatureController = TextEditingController();

  void sendRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please log in to submit a request")),
      );
      return;
    }

    try {
      final requestRef = await FirebaseFirestore.instance.collection("medicine_requests").add({
        "hospital_id": user.uid,
        "shipment_type": shipmentType,
        "item_name": itemNameController.text,
        "quantity": quantityController.text,
        "unit": unitController.text,
        "weight": weightController.text,
        "delivery_location": deliveryLocationController.text,
        "pickup_location": shipmentType == "Diagnostic Sample" ? pickupLocationController.text : null,
        "request_type": shipmentType == "Diagnostic Sample" ? "Diagnostic" : requestType,
        "delivery_time": shipmentType == "Diagnostic Sample"
            ? deliveryTimeController.text
            : (requestType == "Normal" ? deliveryTimeController.text : "ASAP"),
        "temperature": temperatureController.text,
        "status": "Pending",
        "timestamp": DateTime.now(),
      });

      // If this is a Diagnostic Sample, create a transport request directly (no distributor step).
      if (shipmentType == "Diagnostic Sample") {
        final now = DateTime.now();
        final deadline = now.add(const Duration(seconds: 90));

        await FirebaseFirestore.instance.collection("transport_requests").add({
          "request_id": requestRef.id,
          "distributor_id": null,
          "pickup_location": pickupLocationController.text,
          "delivery_location": deliveryLocationController.text,
          "item_name": itemNameController.text,
          "quantity": quantityController.text,
          "temperature": temperatureController.text,
          "required_delivery_time": deliveryTimeController.text,
          "request_type": "Diagnostic",
          "bidding_start_time": Timestamp.fromDate(now),
          "bidding_deadline": Timestamp.fromDate(deadline),
          "deadline_extended": false,
          "status": "bidding",
          "timestamp": Timestamp.fromDate(now),
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Medicine Request Sent")),
      );

      itemNameController.clear();
      quantityController.clear();
      unitController.clear();
      weightController.clear();
      pickupLocationController.clear();
      deliveryLocationController.clear();
      deliveryTimeController.clear();
      temperatureController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $e')),
      );
    }
  }

  @override
  void dispose() {
    itemNameController.dispose();
    quantityController.dispose();
    unitController.dispose();
    weightController.dispose();
    pickupLocationController.dispose();
    deliveryLocationController.dispose();
    deliveryTimeController.dispose();
    temperatureController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text("Request Medicine")),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Shipment Type
              DropdownButtonFormField(
                value: shipmentType,
                items: const [
                  DropdownMenuItem(value: "Medicine", child: Text("Medicine")),
                  DropdownMenuItem(value: "Diagnostic Sample", child: Text("Diagnostic Sample")),
                ],
                onChanged: (value) {
                  setState(() {
                    shipmentType = value!;
                  });
                },
              ),

              const SizedBox(height: 20),

              if (shipmentType == "Medicine") ...[
                // Item Details
                TextField(
                  controller: itemNameController,
                  decoration: const InputDecoration(labelText: "Item Name"),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: quantityController,
                  decoration: const InputDecoration(labelText: "Quantity"),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: unitController,
                  decoration: const InputDecoration(labelText: "Unit (boxes / vials / units)"),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: weightController,
                  decoration: const InputDecoration(labelText: "Approx Weight (optional)"),
                ),

                const SizedBox(height: 20),

                // Delivery Details
                TextField(
                  controller: deliveryLocationController,
                  decoration: const InputDecoration(labelText: "Delivery Location"),
                ),

                const SizedBox(height: 20),

                // Request type (Normal / Emergency)
                DropdownButtonFormField(
                  value: requestType,
                  items: const [
                    DropdownMenuItem(value: "Normal", child: Text("Normal")),
                    DropdownMenuItem(value: "Emergency", child: Text("Emergency")),
                  ],
                  onChanged: (value) {
                    setState(() {
                      requestType = value!;
                    });
                  },
                ),

                const SizedBox(height: 20),

                if (requestType == "Normal")
                  TextField(
                    controller: deliveryTimeController,
                    decoration: const InputDecoration(
                      labelText: "Required Delivery Time (hours)",
                    ),
                  ),

                const SizedBox(height: 20),

                // Environmental Requirements
                TextField(
                  controller: temperatureController,
                  decoration: const InputDecoration(
                    labelText: "Temperature Requirement (2-8°C / -20°C / Room Temp)",
                  ),
                ),

                const SizedBox(height: 20),
              ] else ...[
                // For Diagnostic Sample, pickup, drop, and delivery time are required.
                TextField(
                  controller: pickupLocationController,
                  decoration: const InputDecoration(labelText: "Pickup Location"),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: deliveryLocationController,
                  decoration: const InputDecoration(labelText: "Drop Location"),
                ),

                const SizedBox(height: 20),

                TextField(
                  controller: deliveryTimeController,
                  decoration: const InputDecoration(
                    labelText: "Required Delivery Time (hours)",
                  ),
                ),

                const SizedBox(height: 20),
              ],

              ElevatedButton(
                onPressed: sendRequest,
                child: const Text("Send Request"),
              )

            ],
          ),
        ),
      ),
    );
  }
}
