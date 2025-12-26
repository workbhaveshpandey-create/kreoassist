# KreoAssist 

> **Empowering Resilience, Ensuring Safety.**


**KreoAssist** is a state-of-the-art Disaster Management and Emergency Assistance application designed to function even when traditional networks fail. Combining **Mesh Networking**, **Hybrid AI**, and **One-Tap SOS**, KreoAssist is your ultimate survival companion.

---

## 🌟 Key Features

### 📡 Offline Mesh Network
- **Communication without Internet**: Connect with nearby devices using Bluetooth and Wi-Fi Direct.
- **Broadcast Alerts**: Send "NEED HELP", "I'M SAFE", or custom messages to everyone in the mesh.
- **Decentralized**: No central server required; resilience in disaster zones.

### 🧠 Hybrid AI Assistant (Online + Offline)
- **Smart Switch**: Automatically switches between **Google Gemini (Online)** and **Gemma-2-2B (Offline)** based on connectivity.
- **Privacy First**: Sensitive queries can be processed locally on your device.
- **First Aid Guidance**: Instant AI-powered instructions for medical emergencies (CPR, Burns, Fractures).

### 🆘 Emergency SOS Dashboard
- **One-Tap SOS**: instantly calls emergency services (112) and sends SMS with your precise GPS coordinates to trusted contacts.
- **Direct Dialers**: Dedicated buttons for Police (100), Fire (101), and Ambulance (102) with auto-dial functionality.
- **Quick Actions**: "I'm Safe" and "Need Help" broadcast chips for rapid status updates.

### 🏥 Interactive First Aid Guide
- **Visual Instructions**: Step-by-step guides for common emergencies.
- **Categorized Library**: Quick access to CPR, Bleeding, Burns, and Choking protocols.
- **AI Integration**: Ask specific questions like "How to treat a snake bite?" for immediate advice.

---

## 🎨 Design & Experience
- **Pitch Black AMOLED Theme**: Saves battery during emergencies and reduces eye strain.
- **Indian Flag Gradient**: Custom UI elements featuring the Saffron-White-Green gradient for a proud identity.
- **Smooth Animations**: Optimized for 90Hz+ high refresh rate displays.

🔮 Future Scope
🗺️ Advanced Offline Navigation
Offline Maps Integration: Implementing Mapbox or OpenStreetMap to allow users to view terrain and navigate safe routes without any internet connection.
Safe Zone Marking: Users can mark "Safe Zones" or "Danger Zones" (e.g., flooded areas) that sync across the mesh network.

##🌐 Expanded Connectivity & IoT

LoRaWAN Integration: Extending communication range from meters to kilometers using external LoRa hardware attachments.
Drone Interface: Capability to connect with rescue drones for aerial surveillance feed and supply drop coordination.
IoT Sensor Support: Interfacing with Arduino/ESP32 based sensors (water level, smoke, seismic) for automated local alerts.

##🗣️ Accessibility & Localization
Multi-Language Support: Adding full support for regional Indian languages (Hindi, Tamil, Bengali, etc.) to ensure accessibility in rural areas.
Voice-First Interface: Hands-free voice commands for SOS and navigation, essential for injured users.

##📦 Resource Management
Crowdsourced Relief Mapping: A feature allowing users to tag locations of available food, water, and medical supplies.
Government API Integration: Direct integration with NDMA (National Disaster Management Authority) APIs for official verified alerts when connectivity is available.

---

## 🛠️ Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **AI Models**: 
  - Online: pollinations
  - Offline: Gemma-2-2B (via `flutter_llama`)
- **Connectivity**: `nearby_connections` (Mesh)
- **Utils**: `geolocator`, `flutter_phone_direct_caller`, `permission_handler`

---
graph TD
    %% External Entities
    User[User]
    GPS[GPS Hardware]
    Web[Pollinations API]
    MeshNodes[Other Mesh Devices]
    
    %% Data Stores
    D1[(Local Database - Contacts/Prefs)]
    D2[(Local AI Model - Gemma-2B)]
    D3[(First Aid JSON Library)]

    %% Processes
    P1((1.0 User Interface / State))
    P2((2.0 Connectivity Manager))
    P3((3.0 AI Processing Engine))
    P4((4.0 SOS Handler))
    P5((5.0 Mesh Controller))

    %% Flow: User Input
    User -- "Input Query" --> P1
    User -- "Tap SOS" --> P1
    
    %% Flow: AI Logic
    P1 -- "Send Query" --> P2
    P2 -- "Check Internet" --> P3
    
    P3 -- "Online? Request API" --> Web
    Web -- "Response Data" --> P3
    
    P3 -- "Offline? Run Inference" --> D2
    D2 -- "Generated Text" --> P3
    P3 -- "Final Answer" --> P1
    
    %% Flow: SOS Logic
    P1 -- "Trigger Emergency" --> P4
    GPS -- "Fetch Coordinates" --> P4
    D1 -- "Read Contact Numbers" --> P4
    P4 -- "Execute Call & SMS" --> User
    P4 -- "Send Alert Data" --> P5
    
    %% Flow: Mesh Network
    P5 -- "Broadcast Packet" --> MeshNodes
    MeshNodes -- "Receive Packet" --> P5
    P5 -- "Update Safety Status" --> P1
    
    %% Flow: First Aid
    P1 -- "Request Guide" --> D3
    D3 -- "Return Steps/Images" --> P1



## 👨‍💻 Author
**Bhavesh Pandey**
- *Building technology for a safer tomorrow.*

---

*© 2025 Kreodev. All Rights Reserved.*
