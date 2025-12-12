# 사용자 안전 (User Safety)

## 기능 개요

사용자 안전 기능은 악성 사용자로부터 사용자를 보호하고 건전한 커뮤니티 환경을 유지하기 위한 기능입니다.

### 목적

- **신고하기 (Report)**: 부적절한 행동을 하는 사용자를 관리자에게 신고
- **차단하기 (Block)**: 특정 사용자의 메시지와 활동을 숨김 처리

### 우선순위

**높음** - 필수 안전 기능

---

## 전제 조건

- 로그인 상태 (인증 필요)
- 타인에 대해서만 기능 수행 가능 (본인 신고/차단 불가)

---

## 기능별 상세 명세

### 1. 사용자 신고 (Report User)

#### 기능 설명

부적절한 사용자를 신고합니다. 신고 사유와 상세 내용을 포함할 수 있습니다.

#### API 명세

**엔드포인트**: `POST /api/reports`

**인증**: 필요 (Access Token)

**요청 본문**:
```json
{
  "targetUserId": "uuid-of-target-user",
  "reason": "spam", // spam, abuse, inappropriate, other
  "description": "상세 신고 내용" // 선택 사항
}
```

**응답** (201 Created):
```json
{
  "message": "신고가 접수되었습니다."
}
```

#### 예외 처리

| 에러 코드 | 상황 |
|----------|------|
| 400 | 필수 필드 누락 |
| 409 | 이미 신고한 사용자 (중복 신고 방지) |
| 404 | 존재하지 않는 사용자 |

---

### 2. 사용자 차단 (Block User)

#### 기능 설명

특정 사용자를 차단하여 해당 사용자의 메시지가 보이지 않도록 하고, 더 이상 매칭되지 않도록 합니다.

#### API 명세

**엔드포인트**: `POST /api/users/block`

**인증**: 필요 (Access Token)

**요청 본문**:
```json
{
  "targetUserId": "uuid-of-target-user"
}
```

**응답** (201 Created):
```json
{
  "message": "사용자를 차단했습니다."
}
```

---

### 3. 차단 목록 조회 (Get Blocked Users)

#### 기능 설명

내가 차단한 사용자 목록을 조회합니다.

#### API 명세

**엔드포인트**: `GET /api/users/blocked`

**인증**: 필요 (Access Token)

**응답** (200 OK):
```json
{
  "blockedUsers": [
    {
      "id": "uuid",
      "nickname": "차단된사용자",
      "blockedAt": "timestamp"
    }
  ]
}
```

---

### 4. 차단 해제 (Unblock User)

#### 기능 설명

차단한 사용자를 차단 해제합니다.

#### API 명세

**엔드포인트**: `DELETE /api/users/block/:targetUserId`

**인증**: 필요 (Access Token)

**응답** (200 OK):
```json
{
  "message": "차단이 해제되었습니다."
}
```

---

## 데이터 모델

### Report 엔티티

```typescript
interface Report {
  id: number;
  reporterId: UUID;    // 신고자
  targetUserId: UUID;  // 신고 대상
  reason: string;      // spam, abuse, inappropriate, other
  description?: string;
  status: 'pending' | 'resolved' | 'dismissed';
  createdAt: Timestamp;
}
```

### Block 엔티티

```typescript
interface Block {
  id: number;
  blockerId: UUID;     // 차단한 사람
  blockedId: UUID;     // 차단된 사람
  createdAt: Timestamp;
}
```
