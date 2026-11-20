#include <time.h> 
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h> 
#include <addons/RTDBHelper.h>
#include <vector>

// 1. WiFi & Firebase Credentials (PRESERVED)
// Credentials live in secrets.h (not committed). Copy secrets.example.h to
// secrets.h in this folder and fill in your own values.
#include "secrets.h"
// 2. Graph Constants & Variables
#define NODES 30 
#define INF 999
int adj[NODES][NODES];

// 3. Firebase Objects
FirebaseData fbdo;
FirebaseData stream;
FirebaseAuth auth;
FirebaseConfig config;

// ---------------- GRAPH SETUP ----------------
void addEdge(int u, int v, int w) {
    if (u >= NODES || v >= NODES) return;
    adj[u][v] = w;
    adj[v][u] = w;
}

void initGraph() {
    for(int i=0; i<NODES; i++)
        for(int j=0; j<NODES; j++)
            adj[i][j] = (i == j) ? 0 : INF;

    // --- GROUND FLOOR ---
    // Top Row
    addEdge(13, 4, 1); addEdge(4, 5, 1); addEdge(5, 6, 1); addEdge(6, 7, 1);
    // Bottom Row
    addEdge(3, 2, 1); addEdge(2, 1, 1); addEdge(1, 10, 1); addEdge(10, 12, 1); addEdge(12, 14, 1);
    // Left side & Mid
    addEdge(13, 9, 1); addEdge(9, 11, 1); addEdge(11, 8, 1); addEdge(8, 3, 1);
    // Right side
    addEdge(7, 10, 1); 
    // Cross connections
    addEdge(4, 3, 1); 

    // --- FIRST FLOOR ---
    // Top Row
    addEdge(27, 28, 1); addEdge(28, 18, 1); addEdge(18, 19, 1); addEdge(19, 20, 1); addEdge(20, 21, 1);
    // Left side & Mid
    addEdge(27, 23, 1); addEdge(23, 25, 1); addEdge(25, 22, 1); addEdge(22, 17, 1);
    // Bottom Row
    addEdge(17, 16, 1); addEdge(16, 15, 1); addEdge(15, 24, 1); addEdge(24, 26, 1);
    // Right side
    addEdge(21, 24, 1); 
    // Cross connections
    addEdge(18, 17, 1); 

    // --- FLOOR TRANSITIONS ---
    addEdge(9, 23, 1);  // Lift 1 <-> Lift 3
    addEdge(11, 25, 2); // Stairs 1 <-> Stairs 3
    addEdge(10, 24, 1); // Lift 2 <-> Lift 4
    addEdge(12, 26, 2); // Stairs 2 <-> Stairs 4
}

// ---------------- DIJKSTRA CORE LOGIC (BIDIRECTIONAL) ----------------
bool dijkstra(int start, int end, FirebaseJson &jsonResponse) {
    if (start < 1 || start >= NODES || end < 1 || end >= NODES) {
        jsonResponse.set("error", "Invalid Node range");
        return false;
    }

    if (start == end) {
        FirebaseJsonArray pathArr;
        pathArr.add(start);
        jsonResponse.clear();
        jsonResponse.set("path", pathArr);
        jsonResponse.set("cost", 0);
        jsonResponse.set("destinationReached", true);
        return true;
    }

    int distF[NODES], distB[NODES];
    int parentF[NODES], parentB[NODES];
    bool visitedF[NODES], visitedB[NODES];

    for(int i=0; i<NODES; i++) {
        distF[i] = distB[i] = INF;
        parentF[i] = parentB[i] = -1;
        visitedF[i] = visitedB[i] = false;
    }

    distF[start] = 0;
    distB[end] = 0;

    int intersectNode = -1;
    int minPath = INF;

    // Run searches from both ends simultaneously
    for (int count = 1; count < NODES; count++) {
        // Forward Step
        int uF = -1;
        for (int j = 1; j < NODES; j++) {
            if (!visitedF[j] && (uF == -1 || distF[j] < distF[uF])) uF = j;
        }
        
        if (uF != -1 && distF[uF] != INF) {
            visitedF[uF] = true;
            for (int v = 1; v < NODES; v++) {
                if (adj[uF][v] != INF) {
                    if (distF[uF] + adj[uF][v] < distF[v]) {
                        distF[v] = distF[uF] + adj[uF][v];
                        parentF[v] = uF;
                    }
                }
            }
            if (visitedB[uF]) {
                if (distF[uF] + distB[uF] < minPath) {
                    minPath = distF[uF] + distB[uF];
                    intersectNode = uF;
                }
            }
        }

        // Backward Step
        int uB = -1;
        for (int j = 1; j < NODES; j++) {
            if (!visitedB[j] && (uB == -1 || distB[j] < distB[uB])) uB = j;
        }

        if (uB != -1 && distB[uB] != INF) {
            visitedB[uB] = true;
            for (int v = 1; v < NODES; v++) {
                if (adj[uB][v] != INF) {
                    if (distB[uB] + adj[uB][v] < distB[v]) {
                        distB[v] = distB[uB] + adj[uB][v];
                        parentB[v] = uB;
                    }
                }
            }
            if (visitedF[uB]) {
                if (distF[uB] + distB[uB] < minPath) {
                    minPath = distF[uB] + distB[uB];
                    intersectNode = uB;
                }
            }
        }
        
        // Termination condition
        if (intersectNode != -1 && uF != -1 && uB != -1) {
            if (distF[uF] + distB[uB] >= minPath) break;
        }
    }

    if (intersectNode == -1) {
        jsonResponse.set("error", "No path found");
        return false;
    }

    // Reconstruct Path: [start...intersectNode...end]
    std::vector<int> path;
    for (int v = intersectNode; v != -1; v = parentF[v]) 
        path.insert(path.begin(), v);
    for (int v = parentB[intersectNode]; v != -1; v = parentB[v]) 
        path.push_back(v);

    FirebaseJsonArray pathArr;
    for (int node : path) { 
        pathArr.add(node);
    }

    jsonResponse.clear();
    jsonResponse.set("path", pathArr);
    jsonResponse.set("cost", minPath);
    jsonResponse.set("destinationReached", (start == end));
    
    return true;
}

// ---------------- FIREBASE STREAM CALLBACK ----------------
void streamCallback(FirebaseStream data) {
  if (data.dataType() == "json") {
    FirebaseJson &json = data.jsonObject();
    FirebaseJsonData startData, endData;
    
    json.get(startData, "start_node");
    json.get(endData, "end_node");

    int start = startData.intValue;
    int end = endData.intValue;

    if (start > 0 && end > 0) {
      Serial.printf("Calculating path from %d to %d\n", start, end);
      FirebaseJson resultJson; 
      if (dijkstra(start, end, resultJson)) {
        if (Firebase.RTDB.setJSON(&fbdo, "/navigation_system/result", &resultJson)) {
          Serial.println("Result uploaded to Firebase!");
        } else {
          Serial.println("Upload failed: " + fbdo.errorReason());
        }
      }
    }
  }
}

void streamTimeoutCallback(bool timeout) {
  if (timeout) Serial.println("Stream timeout, resuming...");
}

// ---------------- SETUP & LOOP ----------------
void setup() {
  Serial.begin(115200);
  initGraph();

  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n[1] Connected to WiFi!");

  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  time_t now = time(nullptr);
  while (now < 8 * 3600 * 2) {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
  }
  Serial.println("\n[2] Time Synced!");

  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  
  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("[3] Anonymous Sign-Up Success!");
  } else {
    Serial.printf("[3] Sign-Up Error: %s\n", config.signer.signupError.message.c_str());
  }

  config.token_status_callback = tokenStatusCallback;
  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  Serial.print("Waiting for Firebase Ready");
  unsigned long startTime = millis();
  while (!Firebase.ready() && (millis() - startTime < 30000)) {
    delay(500);
    Serial.print(".");
  }

  if (Firebase.ready()) {
    Serial.println("\n[4] Firebase is READY!");
    Firebase.RTDB.setString(&fbdo, "/test_connection", "ESP32 is Online!");

    if (!Firebase.RTDB.beginStream(&stream, "/navigation_system/request")) {
      Serial.println("[5] Stream Error: " + stream.errorReason());
    } else {  
      Serial.println("[5] Stream Started Successfully!");
    }
    Firebase.RTDB.setStreamCallback(&stream, streamCallback, streamTimeoutCallback);
  } else {
    Serial.println("\n[4] Firebase Connection FAILED (Timeout).");
  }
}

void loop() {
  static unsigned long lastReadyCheck = 0;
  if (millis() - lastReadyCheck > 1000) {
    lastReadyCheck = millis();
    Firebase.ready(); 
  }
}