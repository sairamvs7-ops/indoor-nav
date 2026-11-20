#include <time.h> 
#include <WiFi.h>
#include <Firebase_ESP_Client.h>
#include <addons/TokenHelper.h> 
#include <addons/RTDBHelper.h>

// 1. WiFi & Firebase Credentials
// Credentials live in secrets.h (not committed). Copy secrets.example.h to
// secrets.h in this folder and fill in your own values.
#include "secrets.h"
// 2. Graph Constants & Variables
#define NODES 28 // 1-27 IDs used
#define INF 999
int adj[NODES][NODES];

// 3. Firebase Objects
FirebaseData fbdo;
FirebaseData stream;
FirebaseAuth auth;
FirebaseConfig config;

// ---------------- GRAPH SETUP ----------------
void addEdge(int u, int v, int w) {
    adj[u][v] = w;
    adj[v][u] = w;
}

void initGraph() {
    for(int i=0; i<NODES; i++)
        for(int j=0; j<NODES; j++)
            adj[i][j] = (i == j) ? 0 : INF;

    // --- GROUND FLOOR ---
    addEdge(1, 2, 1); addEdge(2, 3, 1);
    addEdge(4, 5, 1); addEdge(5, 6, 1); addEdge(6, 7, 1);
    addEdge(3, 4, 1); 
    addEdge(8, 4, 1);   
    addEdge(9, 4, 1);   
    addEdge(11, 4, 1);  
    addEdge(10, 7, 1);  
    addEdge(12, 7, 1);  
    addEdge(13, 1, 1);  
    addEdge(14, 7, 1);  

    // --- FIRST FLOOR ---
    addEdge(15, 16, 1); addEdge(16, 17, 1); addEdge(17, 18, 1);
    addEdge(18, 19, 1); addEdge(19, 20, 1); addEdge(20, 21, 1);
    addEdge(22, 18, 1); 
    addEdge(23, 15, 1); 
    addEdge(25, 15, 1); 
    addEdge(24, 21, 1); 
    addEdge(26, 21, 1); 
    addEdge(27, 15, 1); 

    // --- FLOOR TRANSITIONS ---
    addEdge(9, 23, 1);  
    addEdge(10, 24, 1); 
    addEdge(11, 25, 2); 
    addEdge(12, 26, 2); 
}

// ---------------- DIJKSTRA CORE LOGIC ----------------
bool dijkstra(int start, int end, FirebaseJson &jsonResponse) {
    int dist[NODES];
    int parent[NODES];
    bool visited[NODES];

    for(int i=0; i<NODES; i++) {
        dist[i] = INF;
        parent[i] = -1;
        visited[i] = false;
    }

    dist[start] = 0;

    for(int i=1; i<NODES; i++) {
        int u = -1;
        for(int j=1; j<NODES; j++) {
            if(!visited[j] && (u == -1 || dist[j] < dist[u]))
                u = j;
        }

        if(u == -1 || dist[u] == INF) break;
        visited[u] = true;

        for(int v=1; v<NODES; v++) {
            if(adj[u][v] != INF) {
                if(dist[u] + adj[u][v] < dist[v]) {
                    dist[v] = dist[u] + adj[u][v];
                    parent[v] = u;
                }
            }
        }
    }
  
    if (dist[end] == INF) {
        jsonResponse.set("error", "No path found");
        return false;
    }

    std::vector<int> path;
    for(int v = end; v != -1; v = parent[v])
        path.insert(path.begin(), v);

    FirebaseJsonArray pathArr;
    for (int node : path) { 
        pathArr.add(node);
    }

    jsonResponse.clear();
    jsonResponse.set("path", pathArr);
    jsonResponse.set("cost", dist[end]);
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

  // 1. WiFi Connection
  WiFi.begin(ssid, password);
  Serial.print("Connecting to WiFi");
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\n[1] Connected to WiFi!");

  // 2. Time Sync
  configTime(0, 0, "pool.ntp.org", "time.nist.gov");
  time_t now = time(nullptr);
  while (now < 8 * 3600 * 2) {
    delay(500);
    Serial.print(".");
    now = time(nullptr);
  }
  Serial.println("\n[2] Time Synced!");

  // 3. Initialize Firebase
  config.api_key = API_KEY;
  config.database_url = DATABASE_URL;
  
  // Anonymous Sign-Up
  if (Firebase.signUp(&config, &auth, "", "")) {
    Serial.println("[3] Anonymous Sign-Up Success!");
  } else {
    Serial.printf("[3] Sign-Up Error: %s\n", config.signer.signupError.message.c_str());
  }

  config.token_status_callback = tokenStatusCallback;

  Firebase.begin(&config, &auth);
  Firebase.reconnectWiFi(true);

  // 4. Wait for Connection
  Serial.print("Waiting for Firebase Ready");
  unsigned long startTime = millis();
  while (!Firebase.ready() && (millis() - startTime < 30000)) {
    delay(500);
    Serial.print(".");
  }

  if (Firebase.ready()) {
    Serial.println("\n[4] Firebase is READY!");
    Firebase.RTDB.setString(&fbdo, "/test_connection", "ESP32 is Online!");

    // 5. Start the Stream
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
  Firebase.ready(); 
}