# 카카오 로그인 연동 가이드

카카오 로그인을 구현하기 위해서는 **Kakao Developers** 콘솔에서 애플리케이션을 등록하고, 발급받은 키를 앱에 설정해야 합니다.

## 1. 카카오 개발자 계정 및 앱 등록

1.  **Kakao Developers 접속**
    *   [Kakao Developers](https://developers.kakao.com/) 에 접속하여 카카오 계정으로 로그인합니다.
    *   '내 애플리케이션' 메뉴로 이동합니다.
    *   bulpann@naver.com 계정으로 로그인
2.  **애플리케이션 추가**
    *   '애플리케이션 추가하기' 버튼을 클릭합니다.
    *   **앱 아이콘**: 앱 아이콘을 등록합니다 (선택).
    *   **앱 이름**: `YEO.PE` (또는 원하시는 앱 이름)
    *   **사업자 명**: `개인` 또는 사업자명 입력.
    *   카테고리 선택 후 '저장'을 누릅니다.

3.  **네이티브 앱 키 확인**
    *   생성된 앱을 클릭하여 상세 페이지로 들어갑니다.  com.oviwan.YEO.PE
    *   **요약 정보** 탭에서 **[네이티브 앱 키]**를 확인하고 복사해둡니다. (이 키가 `Info.plist`에 들어갈 `KAKAO_APP_KEY`입니다.)
       159b87acd87f2a049822bfdb62c3a18a

## 2. 플랫폼 설정 (iOS)

1.  **플랫폼 등록**
    *   왼쪽 메뉴의 **[플랫폼]**을 클릭합니다.
    *   **iOS 플랫폼 등록** 버튼을 클릭합니다.

2.  **Bundle ID 입력**
    *   **번들 ID**: Xcode 프로젝트의 Bundle Identifier를 입력합니다.
        *   현재 프로젝트의 Bundle ID: `com.yeo.pe` (확인 필요: Xcode -> Project Target -> General 탭에서 확인 가능)
    *   **마켓 URL**: 앱스토어 링크가 없다면 비워두거나 임의의 주소를 넣어도 됩니다.
    *   '저장'을 누릅니다.

## 3. 카카오 로그인 활성화

1.  **활성화 설정**
    *   왼쪽 메뉴의 **[카카오 로그인]**을 클릭합니다.
    *   **활성화 설정**의 상태를 `OFF` -> `ON`으로 변경합니다.

2.  **동의항목 설정** (사용자 정보 가져오기)
    *   왼쪽 메뉴의 **[카카오 로그인] > [동의항목]**을 클릭합니다.
    *   필요한 정보(닉네임, 이메일 등)를 설정합니다.
        *   **닉네임**: 필수 동의 (또는 선택 동의)
        *   **이메일**: 권한 필요 (비즈니스 앱 전환 전에는 '선택 동의'만 가능할 수 있음)
    *   수집 목적을 간단히 입력하고 저장합니다.

## 4. Xcode 프로젝트 설정 (`Info.plist`)

`YEO-PE-Info.plist` 파일에 다음 설정을 추가해야 합니다.

1.  **LSApplicationQueriesSchemes 추가** (카카오톡 앱 실행 허용)
    ```xml
    <key>LSApplicationQueriesSchemes</key>
    <array>
        <string>kakaokompassauth</string>
        <string>kakaolink</string>
    </array>
    ```

2.  **URL Types 추가** (카카오톡 로그인 후 앱으로 복귀)
    ```xml
    <key>CFBundleURLTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeRole</key>
            <string>Editor</string>
            <key>CFBundleURLSchemes</key>
            <array>
                <string>kakao${NATIVE_APP_KEY}</string> 
                <!-- 예: kakao123456789 (네이티브 앱 키 앞에 kakao를 붙여야 함) -->
            </array>
        </dict>
    </array>
    ```

3.  **App Key 설정** (필요한 경우, 보통 코드나 xcconfig에서 관리)
    *   `Global.swift` 또는 `AppConfig` 등에서 초기화 시 사용됩니다.

## 5. 초기화 코드 확인

`AppDelegate` 또는 앱 시작 부분에서 SDK를 초기화해야 합니다.

```swift
import KakaoSDKCommon

// application(_:didFinishLaunchingWithOptions:) 내부
KakaoSDK.initSDK(appKey: "YOUR_NATIVE_APP_KEY")
```

현재 프로젝트의 `KakaoAuthManager.swift`가 이미 구현되어 있으므로, 키 설정만 올바르게 되면 작동할 것입니다.
