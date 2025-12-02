# YEO.PE 기능 명세서 (Functional Specification)

> **프로젝트**: YEO.PE  
> **버전**: 1.0  
> **작성일**: 2024년 11월  
> **참조 문서**: 
> - [프로젝트 기획서](../planning/PROJECT_SPEC.md)
> - [기술 설계서](../architecture/architecture.md)

---

## 목차

1. [문서 개요](#문서-개요)
2. [기능 목록](#기능-목록)
3. [기능별 상세 명세](#기능별-상세-명세)
4. [에러 코드 정의](#에러-코드-정의)
5. [비기능 요구사항](#비기능-요구사항)

---

## 문서 개요

### 목적

이 문서는 YEO.PE 서비스의 각 기능에 대한 상세 명세를 제공합니다. 개발자, QA, 기획자가 참고할 수 있는 구현 가이드로 활용됩니다.

### 문서 구조

- **메인 문서**: 이 문서 (FUNCTIONAL_SPEC.md)
- **기능별 상세 문서**: `docs/functional-spec/` 폴더 내 개별 문서

### 문서 사용 가이드

1. **개발자**: 각 기능의 동작 방식, API 명세, 예외 처리 확인
2. **QA**: 테스트 케이스 작성 및 검증 기준 확인
3. **기획자**: 기능 요구사항 및 UI/UX 플로우 확인

---

## 기능 목록

### 구현 완료 기능 (MVP Phase 1-6)

| 우선순위 | 기능명 | 문서 | 상태 |
|---------|--------|------|------|
| 1 | 사용자 인증 | [01-authentication.md](./01-authentication.md) | ✅ 완료 |
| 2 | 방 관리 | [02-room-management.md](./02-room-management.md) | ✅ 완료 |
| 3 | 실시간 채팅 | [03-realtime-chat.md](./03-realtime-chat.md) | ✅ 완료 |
| 4 | 사용자 프로필 | [07-user-profile.md](./07-user-profile.md) | ✅ 완료 |
| 5 | TTL 자동 정리 | [08-ttl-management.md](./08-ttl-management.md) | ✅ 완료 |

### 예정 기능

| 우선순위 | 기능명 | 문서 | 상태 |
|---------|--------|------|------|
| 6 | BLE 탐색 | [04-ble-discovery.md](./04-ble-discovery.md) | 🚧 예정 |
| 7 | 파일 업로드 | [05-file-upload.md](./05-file-upload.md) | 🚧 예정 |
| 8 | 푸시 알림 | [06-push-notification.md](./06-push-notification.md) | 🚧 예정 |

---

## 기능별 상세 명세

각 기능의 상세 명세는 다음 문서에서 확인할 수 있습니다:

### 1. 사용자 인증 (Authentication)
- **문서**: [01-authentication.md](./01-authentication.md)
- **주요 기능**:
  - 이메일 회원가입
  - 이메일 로그인
  - JWT 토큰 기반 인증
  - 토큰 갱신 (Refresh Token)
  - 로그아웃

### 2. 방 관리 (Room Management)
- **문서**: [02-room-management.md](./02-room-management.md)
- **주요 기능**:
  - 방 생성
  - 근처 활성 방 목록 조회
  - 내가 참여 중인 방 목록 조회
  - 방 상세 정보 조회
  - 방 참여
  - 방 나가기
  - 방 멤버 목록 조회

### 3. 실시간 채팅 (Real-time Chat)
- **문서**: [03-realtime-chat.md](./03-realtime-chat.md)
- **주요 기능**:
  - WebSocket 연결 및 인증
  - 실시간 메시지 전송/수신
  - 방 참여/나가기 (WebSocket)
  - 타이핑 인디케이터
  - 메시지 목록 조회 (REST API)
  - 메시지 삭제

### 4. BLE 탐색 (BLE Discovery)
- **문서**: [04-ble-discovery.md](./04-ble-discovery.md)
- **상태**: 🚧 예정
- **주요 기능**:
  - BLE 스캔 시작/중지
  - 주변 사용자 탐색
  - RSSI 기반 거리 계산
  - 방 초대 프로토콜

### 5. 파일 업로드 (File Upload)
- **문서**: [05-file-upload.md](./05-file-upload.md)
- **상태**: 🚧 예정
- **주요 기능**:
  - 이미지 업로드
  - 썸네일 생성
  - OCI Object Storage 연동

### 6. 푸시 알림 (Push Notification)
- **문서**: [06-push-notification.md](./06-push-notification.md)
- **상태**: 🚧 예정
- **주요 기능**:
  - FCM/APNs 연동
  - 방 생성 알림
  - 메시지 알림

### 7. 사용자 프로필 (User Profile)
- **문서**: [07-user-profile.md](./07-user-profile.md)
- **주요 기능**:
  - 사용자 정보 조회
  - 닉네임 수정
  - 설정 변경

### 8. TTL 자동 정리 (TTL Management)
- **문서**: [08-ttl-management.md](./08-ttl-management.md)
- **주요 기능**:
  - 만료된 방 자동 삭제
  - 만료된 메시지 자동 삭제
  - 스케줄러 관리

---

## 에러 코드 정의

### HTTP 상태 코드

| 코드 | 의미 | 사용 시나리오 |
|------|------|--------------|
| 200 | OK | 성공적인 요청 |
| 201 | Created | 리소스 생성 성공 |
| 400 | Bad Request | 잘못된 요청 (입력 검증 실패) |
| 401 | Unauthorized | 인증 실패 (토큰 없음/만료) |
| 403 | Forbidden | 권한 없음 |
| 404 | Not Found | 리소스를 찾을 수 없음 |
| 409 | Conflict | 리소스 충돌 (중복 등) |
| 429 | Too Many Requests | Rate Limit 초과 |
| 500 | Internal Server Error | 서버 내부 오류 |

### 커스텀 에러 메시지

각 기능 문서에서 상세한 에러 케이스를 확인할 수 있습니다.

---

## 비기능 요구사항

### 성능

- **API 응답 시간**: 평균 200ms 이하
- **WebSocket 지연**: 평균 100ms 이하
- **동시 접속**: 방당 최대 100명
- **데이터베이스 쿼리**: 복잡한 쿼리 500ms 이하

### 보안

- **인증**: JWT 토큰 기반 (Access Token 7일, Refresh Token 30일)
- **비밀번호**: bcrypt 해싱 (salt rounds: 10)
- **Rate Limiting**: 
  - 인증 API: 5회/분
  - 방 생성: 10회/시간
  - 메시지 전송: 30회/분
- **입력 검증**: 모든 사용자 입력 검증 및 sanitization

### 가용성

- **서버 가동률**: 99% 이상
- **데이터 백업**: 일일 자동 백업
- **모니터링**: 로그 및 메트릭 수집

### 확장성

- **수평 확장**: 서버 인스턴스 추가 가능
- **데이터베이스**: 읽기 전용 복제본 지원
- **캐싱**: Redis를 통한 세션 및 데이터 캐싱

---

## 문서 업데이트 이력

| 날짜 | 버전 | 변경 내용 | 작성자 |
|------|------|-----------|--------|
| 2024-11 | 1.0 | 초기 문서 작성 | YEO.PE Team |

---

## 참고 자료

- [프로젝트 기획서](../planning/PROJECT_SPEC.md)
- [기술 설계서](../architecture/architecture.md)
- [프로젝트 루트 README](../../README.md)

