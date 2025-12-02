# iOS Project Setup

Please create a new iOS project in this directory using Xcode.

## Instructions

1.  Open **Xcode**.
2.  Select **Create a new Xcode project**.
3.  Choose **App** under the iOS tab.
4.  Enter the following details:
    *   **Product Name**: `YEO.PE` (or `YeoPe`)
    *   **Organization Identifier**: `com.yeope` (or your preferred ID)
    *   **Interface**: **SwiftUI**
    *   **Language**: **Swift**
    *   **Storage**: **None** (We will use our own backend)
5.  Save the project in: `/Users/home/Documents/YEO.PE/ios`
    *   Ensure the project file (`YEO.PE.xcodeproj`) ends up inside `ios/`.
6.  Once created, please notify the agent so we can proceed with the code structure.

## Dependencies (Planned)

We will likely use **Swift Package Manager (SPM)** for:
*   `Alamofire` (Networking)
*   `Socket.IO-Client-Swift` (Real-time Chat)
*   `Kingfisher` (Image Loading)
*   `Lottie` (Animations - optional)
