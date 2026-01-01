# YEO.PE Server Recovery & Setup Guide

본 문서는 서비스를 다른 서버로 이전하거나, 전면 리셋 후 복구할 때 필요한 필수 절차와 구성 요소에 대해 설명합니다.

---

## 1. 데이터베이스 초기화 (Baseline)

서비스를 처음 시작하거나 DB를 리셋했을 때, 가장 먼저 실행해야 하는 스크립트는 `server/database/init.sql`입니다.

### 초기 설정 필수 항목
- **DB 생성**: `CREATE DATABASE yeope;`
- **사용자 생성**: `yeope_user` (비밀번호: `yeope_password_2024`)
- **스키마 생성**: `CREATE SCHEMA yeope_schema;`
- **권한**: `yeope_user`에게 `yeope_schema` 내 모든 테이블 및 시퀀스 권한 부여

> [!NOTE]
> `docker-compose.yml`을 통해 Postgres 컨테이너를 처음 띄우면 `init.sql`이 자동으로 마운트되어 실행되도록 설정되어 있습니다.

---

## 2. 자동 마이그레이션 프로세스

서버(`index.js`)가 시작될 때마다 `server/database/` 폴더 내의 마이그레이션 파일들을 순차적으로 체크하고 실행합니다.

### 실행 순서 (중요)
1. `migration_ensure_blocked_users.sql`: 차단 테이블 존재 확인
2. `migration_block_nickname.sql`: 차단 닉네임 컬럼 추가
3. `migration_add_profile_image.sql`: 프로필 이미지 URL 컬럼 추가
4. `migration_add_ble_uids.sql`: BLE UID 테이블 생성
5. `migration_add_push_tokens.sql`: 푸시 토큰 테이블 생성
6. `migration_block_report.sql`: 신고하기 테이블 생성

### 참고 사항
- 모든 파일은 `IF NOT EXISTS` 또는 `ADD COLUMN IF NOT EXISTS`를 사용하여 중복 실행 시에도 안전하도록(Idempotent) 설계되었습니다.
- 서버 이전 시, 코드를 실행하기만 하면 DB 스키마는 자동으로 최신 상태로 업데이트됩니다.

---

## 3. 필수 환경 변수 (.env)

서버 복구 시 아래 변수들이 정확히 설정되어 있지 않으면 서비스가 정상 작동하지 않습니다.

| 변수 | 설명 | 비고 |
| :--- | :--- | :--- |
| `DB_HOST` | PostgreSQL 호스트 주소 | Docker 시 `postgres` |
| `REDIS_HOST` | Redis 호스트 주소 | Docker 시 `yeope-redis` |
| `ADMIN_PASSWORD` | 어드민 패널 접속 비밀번호 | 기본값 존재 |
| `FCM_SERVICE_ACCOUNT_PATH` | Firebase 서비스 계정 키 경로 | 푸시 발송 필수 |
| `NODE_ENV` | `production` 또는 `development` | 로그 레벨 및 보안 설정 |

---

## 4. 백업 및 복구 대상 (Stay-in-Sync)

단순히 DB 테이블만 복구하는 것이 아니라, 아래 데이터/설정도 함께 이전해야 합니다.

1. **사용자 업로드 이미지**: `server/public/uploads` 폴더 (Docker 볼륨 확인)
2. **SSL 인증서**: `server/nginx/ssl` (Cloudflare 인증서 등)
3. **Firebase 키**: `server/config/firebase-service-account.json`
4. **Postgres 데이터**: `postgres_data` 볼륨 (영구 보관 필요)

---

## 5. 서비스 이전/복구 체크리스트

1. [ ] 새로운 환경에 Docker/Docker Compose 설치
2. [ ] `./server/.env` 파일 복사 및 환경에 맞게 수정
3. [ ] Firebase 서비스 계정 JSON 파일 배치
4. [ ] SSL 인증서 파일 확인 (`.crt`, `.key`)
5. [ ] `docker compose up -d --build` 실행
6. [ ] `docker logs yeope-app`를 통해 `✅ Migration executed successfully` 메시지 확인
7. [ ] 어드민 패널(`:3000/admin`) 접속 테스트
