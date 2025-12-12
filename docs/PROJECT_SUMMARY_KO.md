# YEO.PE 프로젝트 분석 보고서

## 1. 프로젝트 개요
**YEO.PE**는 GPS 없이 **BLE(Bluetooth Low Energy)** 신호 강도를 이용하여 물리적으로 가까운 사용자를 연결하는 **휘발성 근거리 소셜 네트워크 서비스**입니다.

- **핵심 가치**: "지도 밖에서 만나는 진짜 연결"
- **주요 특징**:
    - **근거리 탐색**: BLE 신호 기반 사용자 발견.
    - **휘발성**: 모든 채팅방과 데이터는 24시간 후 자동 소멸 (TTL).
    - **익명성**: 닉네임 마스킹을 통한 프라이버시 보장.
    - **실시간성**: Socket.io를 활용한 즉각적인 메시징.

## 2. 기술 스택 (Tech Stack)

### Server (Backend)
- **Runtime**: Node.js (v18+)
- **Framework**: Express.js (REST API), Socket.io (WebSocket)
- **Database**: PostgreSQL (메인 DB), Redis (캐싱, 세션, Pub/Sub)
- **Infrastructure**: Oracle Cloud Infrastructure (OCI), Nginx (Reverse Proxy)
- **Libraries**: `pg`, `ioredis`, `jsonwebtoken` (JWT), `winston` (Logging), `firebase-admin` (FCM)

### Client (Mobile) - *개발 중*
- **iOS**: Swift, CoreBluetooth
- **Android**: Kotlin, Android BLE

## 3. 프로젝트 구조 (Project Structure)

### `docs/` (문서화)
프로젝트는 체계적인 문서화 전략을 따릅니다:
- **`planning/`**: 기획 의도 및 요구사항 정의 (`PROJECT_SPEC.md`).
- **`architecture/`**: 시스템 아키텍처, DB 스키마, API 설계 (`architecture.md`).
- **`functional-spec/`**: 기능별 상세 명세 (인증, 채팅, BLE 등).
- **`development/`**: 개발 가이드라인 및 컨벤션.

### `server/` (백엔드)
관심사 분리를 위한 **Layered Architecture**를 채택했습니다:
- **`src/config/`**: 환경 변수 및 DB 연결 설정.
- **`src/routes/`**: API 엔드포인트 라우팅.
- **`src/controllers/`**: 요청 처리 및 응답 반환.
- **`src/services/`**: 비즈니스 로직 수행.
- **`src/models/`**: 데이터베이스 쿼리 및 데이터 조작.
- **`src/socket/`**: 실시간 이벤트 핸들링.
- **`src/middleware/`**: 인증(Auth), 유효성 검사, 에러 처리.

## 4. 현재 개발 상태
- **✅ Server**: MVP 단계 완료 (회원가입, 방 생성/참여, 실시간 채팅, TTL 자동 삭제, 신고/차단).
- **✅ Mobile**: iOS 앱 MVP 구현 완료 (SwiftUI).
- **🚀 Deployment**: `yeo.pe` 도메인 연결 완료.
