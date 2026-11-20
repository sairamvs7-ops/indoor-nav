import 'dart:convert';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/nav_data.dart';

class ApiService {
  final _db = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  void _handleFirebaseError(dynamic error, String operationType, String path) {
    final errInfo = {
      "error": error.toString(),
      "operationType": operationType,
      "path": path,
      "authInfo": {
        "userId": _auth.currentUser?.uid,
        "email": _auth.currentUser?.email,
        "emailVerified": _auth.currentUser?.emailVerified,
        "isAnonymous": _auth.currentUser?.isAnonymous,
        "providerInfo": _auth.currentUser?.providerData.map((p) => {
          "providerId": p.providerId,
          "displayName": p.displayName,
          "email": p.email,
          "photoUrl": p.photoURL
        }).toList() ?? []
      }
    };
    print('Firebase Error: ${jsonEncode(errInfo)}');
    throw Exception(jsonEncode(errInfo));
  }

  Future<NavData> fetchNextNode(int markerId, int? destinationId) async {
    print("Sending request to Firebase: start_node=$markerId, end_node=$destinationId");
    try {
      // 1. Clear old result to ensure we get a fresh one
      const resultPath = "navigation_system/result";
      try {
        await _db.child(resultPath).remove();
      } catch (e) {
        if (e.toString().contains('permission_denied')) {
          _handleFirebaseError(e, 'delete', resultPath);
        }
      }

      // 2. Send request to ESP32 via Firebase
      const requestPath = "navigation_system/request";
      try {
        await _db.child(requestPath).set({
          "start_node": markerId,
          "end_node": destinationId ?? 10, // Default to 10 if not set
        }).timeout(const Duration(seconds: 5));
      } catch (e) {
        if (e.toString().contains('permission_denied')) {
          _handleFirebaseError(e, 'write', requestPath);
        } else {
          rethrow;
        }
      }
      
      print("Request successfully written to Firebase!");

      // 3. Wait for result from ESP32 (polling for 10 seconds)
      DataSnapshot? snapshot;
      for (int i = 0; i < 20; i++) {
        try {
          snapshot = await _db.child(resultPath).get();
        } catch (e) {
          if (e.toString().contains('permission_denied')) {
            _handleFirebaseError(e, 'get', resultPath);
          }
        }
        if (snapshot != null && snapshot.exists) {
          print("Received result from ESP32!");
          break;
        }
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      if (snapshot != null && snapshot.exists) {
        final val = snapshot.value;
        Map<String, dynamic> data;
        
        if (val is String) {
          data = Map<String, dynamic>.from(jsonDecode(val));
        } else if (val is Map) {
          data = Map<String, dynamic>.from(val);
        } else {
          throw Exception("Unexpected data format from Firebase");
        }
        
        return NavData.fromJson(data);
      } else {
        print("Timeout: ESP32 did not respond in time.");
        throw Exception("Timeout waiting for ESP32 pathfinding");
      }
    } catch (e) {
      print("Firebase Operation Error: $e");
      // Fallback mock data
      return NavData(
        next: markerId + 1,
        instruction: "Go straight to Room ${101 + markerId}",
        destinationReached: false,
        path: [
          PathStep(id: markerId, name: "Current Location", roomNumber: "R$markerId"),
          PathStep(id: markerId + 1, name: "Corridor A", roomNumber: "C1"),
          PathStep(id: markerId + 2, name: "Lobby", roomNumber: "L1"),
          PathStep(id: destinationId ?? 10, name: "Destination", roomNumber: "R${destinationId ?? 10}"),
        ],
      );
    }
  }
}
