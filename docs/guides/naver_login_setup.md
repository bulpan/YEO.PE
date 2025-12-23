# 네이버 로그인 연동 가이드

네이버 로그인을 구현하기 위해서는 **Naver Developers** 콘솔에서 애플리케이션을 등록하고, 발급받은 Client ID와 Secret을 앱에 설정해야 합니다.

## 1. 네이버 개발자 센터 계정 및 앱 등록

1.  **Naver Developers 접속**
    *   [Naver Developers](https://developers.naver.com/) 에 접속하여 네이버 계정으로 로그인합니다.
    *   **Application > 애플리케이션 등록** 메뉴로 이동합니다.
        bulpann@naver.com 으로 로그인
2.  **애플리케이션 등록**
    *   **애플리케이션 이름**: `YEO.PE` (또는 원하시는 앱 이름)
    *   **사용 API**: `네이버 로그인`을 선택합니다.
        *   **필수 제공 항목**: `회원이름`, `이메일`, `별명`, `프로필 사진` 등을 '필수'로 체크합니다. (최소한 이메일이나 고유 식별자가 필요합니다)
    *   **환경 추가**: `iOS`를 추가합니다.

3.  **iOS 환경 설정**
    *   **다운로드 URL**: 앱스토어 URL이 없다면 임의의 URL (예: `https://yeo.pe`) 입력.
    *   **URL Scheme**: `yeope` (소문자 권장)
        *   **중요**: 이 값은 프로젝트 코드의 `AppDelegate.swift` 및 `Info.plist`에 설정된 값과 정확히 일치해야 합니다. 현재 프로젝트는 `yeope`로 설정되어 있습니다.

4.  **Client Key 확인**
    *   등록 완료 후 **내 애플리케이션** 목록에서 등록한 앱을 선택합니다.
    *   **개요** 탭에서 **Client ID**와 **Client Secret**을 확인하고 복사해둡니다.

## 2. Xcode 프로젝트 설정 (`Info.plist`)

`YEO-PE-Info.plist` 파일에 다음 설정을 추가해야 합니다. (이미 `kakao` 설정할 때 구조는 잡혀 있습니다)

1.  **LSApplicationQueriesSchemes 추가** (네이버 앱 실행 허용)
    *   `LSApplicationQueriesSchemes` 배열에 다음 항목들을 추가합니다.
    ```xml
    <string>naversearchapp</string>
    <string>naversearchthirdlogin</string>
    ```

2.  **URL Types 추가** (로그인 후 앱 복귀)
    *   `CFBundleURLTypes` 배열 안에 새로운 항목을 추가하거나, 기존 항목의 `CFBundleURLSchemes`에 `yeope`가 있는지 확인합니다.
    ```xml
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>yeope</string> 
        </array>
    </dict>
    ```

## 3. 코드 설정 (`AppDelegate.swift`)

`AppDelegate.swift` 파일의 `didFinishLaunchingWithOptions` 내부에서 정보를 업데이트해야 합니다.

```swift
// Initialize Naver SDK
#if canImport(NaverThirdPartyLogin)
let instance = NaverThirdPartyLoginConnection.getSharedInstance()
instance?.isNaverAppOauthEnable = true
instance?.isInAppOauthEnable = true
instance?.setOnlyPortraitSupportInIphone(true)

// 설정한 값으로 교체하세요
instance?.serviceUrlScheme = "yeope" // Naver Developers의 URL Scheme과 일치
instance?.consumerKey = "YOUR_NAVER_CLIENT_ID" // 발급받은 Client ID
instance?.consumerSecret = "YOUR_NAVER_CLIENT_SECRET" // 발급받은 Client Secret
instance?.appName = "YEO.PE"
#endif
```

## 4. 메모

*   카카오와 달리 네이버는 `Client Secret`도 클라이언트(앱)에 포함해야 합니다.
*   발급받은 키(`Client ID`, `Client Secret`)를 알려주시면 프로젝트에 적용해드릴 수 있습니다.
