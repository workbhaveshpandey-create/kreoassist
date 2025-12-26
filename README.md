# KreoAssist 🚑

> **Empowering Resilience, Ensuring Safety.**
> *Created by Bhavesh Pandey*

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

---

## 🛠️ Tech Stack
- **Framework**: Flutter (Dart)
- **State Management**: Riverpod
- **AI Models**: 
  - Online: Google Gemini Pro
  - Offline: Gemma-2-2B (via `flutter_llama`)
- **Connectivity**: `nearby_connections` (Mesh)
- **Utils**: `geolocator`, `flutter_phone_direct_caller`, `permission_handler`

---

## 🚀 Getting Started

### Prerequisites
- Flutter SDK installed
- Android device (for full feature support including Mesh & Offline AI)

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/kreoassist.git
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run the app:
   ```bash
   flutter run
   ```

---

## 📸 Screenshots
*(Add your screenshots here)*

---

## 👨‍💻 Author
**Bhavesh Pandey**
- *Building technology for a safer tomorrow.*

---

*© 2025 KreoAssist. All Rights Reserved.*
