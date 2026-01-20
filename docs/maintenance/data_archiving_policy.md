# YEO.PE 데이터 보관 및 아카이빙 정책 (Data Retention Policy)

## 1. 개요
YEO.PE는 익명성과 휘발성을 특징으로 하는 채팅 서비스이지만, 관련 법규 준수 및 신고 처리를 위해 **제한된 기간 동안 데이터를 서버에 보관**합니다. 이 문서는 데이터의 생명 주기와 아카이빙 기술 명세를 설명합니다.

## 2. 데이터 수명 주기 (Data Lifecycle)

### 2.1. 활성 상태 (Active)
- **대상**: 생성 후 24시간 이내의 방(Rooms) 및 메시지(Messages)
- **저장소**: 메인 테이블 (`rooms`, `messages`, `room_members`)
- **사용자 접근**: 앱 내에서 자유롭게 조회 및 대화 가능

### 2.2. 아카이브 상태 (Archived)
- **전환 시점**: 생성 후 24시간 경과 시 (TTL 만료)
- **대상**: 만료된 방, 메시지, 참여자 정보
- **동작**: `TTL Service`가 매 시간 실행되어 만료된 데이터를 **아카이브 테이블로 이동** 후 메인 테이블에서 삭제
- **저장소**: 
  - `archived_rooms`
  - `archived_messages`
  - `archived_room_members`
- **사용자 접근**: 앱에서는 "사라짐"으로 처리되어 **조회 불가**. 오직 **어드민 패널**을 통해서만 관리자가 제한적으로 조회 가능 (법적 대응, 신고 확인 용도).

### 2.3. 영구 삭제 (Purged)
- **삭제 시점**: 아카이브 전환 후 **6개월(180일)** 경과 시
- **동작**: 매일 새벽 4시에 실행되는 서버 스케줄러가 보관 기한이 지난 아카이브 데이터를 **영구 삭제(Hard Delete)**
- **복구**: 삭제된 데이터는 복구 불가능

## 3. 기술 명세 (Technical Spec)

### 3.1. Database Schema
아카이브 테이블은 원본 테이블과 유사한 스키마를 가지며 `archived_at` 타임스탬프 필드가 추가됩니다.

```sql
-- Archived Messages Table Specification
CREATE TABLE yeope_schema.archived_messages (
    id UUID PRIMARY KEY,         -- Original Message ID
    room_id UUID,
    user_id UUID,
    type VARCHAR(50),
    content TEXT,
    image_url TEXT,
    created_at TIMESTAMP,
    expires_at TIMESTAMP,
    archived_at TIMESTAMP DEFAULT NOW() -- 이관 시점
);
```

### 3.2. TTL Service Logic (`server/src/services/ttlService.js`)
1. **Move to Archive**: `expires_at < NOW()` 조건의 데이터를 `INSERT INTO archived_... SELECT ...` 쿼리로 복사
2. **Delete from Active**: 복사 성공 후 원본 테이블에서 `DELETE`
3. **Retention Cleanup**: `archived_at < NOW() - 180 days` 조건의 데이터를 `DELETE`

### 3.3. Admin Tool
- **경로**: 어드민 패널 > 아카이브 (Archives)
- **기능**:
  - 유저 ID (`userId`) 기반 발송 내역 검색
  - 메시지 내용 키워드 검색
  - 6개월 이내의 대화 내역 원문 및 메타데이터 확인

## 4. 운영 가이드
- **긴급 데이터 보전 요청**: 수사기관 등의 요청이 있을 경우, 180일이 지나기 전에 DB 백업이나 별도 추출을 수행해야 합니다.
- **정책 변경**: 보관 기간 변경이 필요한 경우 `ttlService.js`의 `cleanupArchivedData` 함수 내 일수(180)를 수정해야 합니다.
