# YEO.PE Functional Specifications

## 1. Core Concept
YEO.PE is a location-based ephemeral chat service. Users discover each other via Bluetooth Low Energy (BLE) and can create temporary chat rooms.

## 2. Connectivity & Background Behavior
### 2.1 BLE Advertising & Scanning
- **Foreground**: The app scans for nearby users and advertises its own presence.
- **Background**:
    - The app MUST continue to advertise its presence (via `bluetooth-peripheral` background mode) using the **Hybrid Strategy** (Service UUID advertising) so other users can discover it even when the phone is in the pocket.
    - Scanning may be reduced or paused to save battery, but the user's "online" status should persist.

### 2.2 Socket Connection
- **Foreground**: Socket is connected to receive real-time updates.
- **Background**:
    - **CRITICAL**: The socket connection MUST remain active in the background to ensure the user appears "online" to others and to maintain the BLE advertising lifecycle if tied to server presence.
    - If the socket disconnects, the server marks the user as "offline" or "inactive," causing them to disappear from other users' radars. Therefore, **do not disconnect the socket manually on background entry.**
    - **Push Notifications**: While the socket is connected in the background, the app should use **Local Notifications** to alert the user of new messages. If the system eventually kills the socket, FCM (Firebase Cloud Messaging) will take over.

## 3. Push Notifications
- **Types**:
    - `NEW_MESSAGE`: Chat message received.
    - `NEARBY_USER`: New user discovered nearby.
    - `ROOM_INVITE`: Invited to a room.
    - `ROOM_CREATED`: A room was created (if subscribed).
- **Deep Linking**: All push notifications must contain standard payloads (`action`, `targetScreen`, `targetId`) to route the user to the correct screen upon tapping.

## 4. UI/UX Guidelines
- **Radar**: Shows nearby users and rooms.
    - **Users**: Based on BLE signal strength.
    - **Rooms**: Based on the creator's location/signal.
- **Room List**:
    - "My Rooms": Rooms the user has joined.
    - "Nearby Rooms": Public rooms created by nearby users.
