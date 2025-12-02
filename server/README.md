# YEO.PE Server

블루투스 기반 휘발성 근거리 채팅 서비스 백엔드 서버

## 기술 스택

- **Runtime**: Node.js 18.x
- **Framework**: Express.js
- **Real-time**: Socket.io
- **Database**: PostgreSQL 13+
- **Cache**: Redis 6+
- **Authentication**: JWT

## 프로젝트 구조

```
server/
├── src/
│   ├── index.js              # 서버 진입점
│   ├── config/               # 설정 파일
│   ├── models/               # 데이터 모델
│   ├── routes/               # API 라우트
│   ├── socket/               # WebSocket 핸들러
│   ├── services/             # 비즈니스 로직
│   ├── middleware/           # 미들웨어
│   └── utils/                # 유틸리티
├── tests/                    # 테스트
└── package.json
```

## 설치 및 실행

### 1. 의존성 설치

```bash
npm install
```

### 2. 환경 변수 설정

`.env.example`을 복사하여 `.env` 파일을 생성하고 필요한 값들을 설정하세요.

```bash
cp .env.example .env
```

### 3. 개발 서버 실행

```bash
npm run dev
```

### 4. 프로덕션 서버 실행

```bash
npm start
```

## 환경 변수

주요 환경 변수는 `.env.example` 파일을 참조하세요.

## 로컬 개발 환경 설정 (Local Development Setup)

### 1. Docker 실행 시 .env 설정
로컬에서 Docker로 데이터베이스와 Redis를 실행하는 경우, `.env` 파일을 다음과 같이 설정해야 합니다.

```env
# Database
DB_HOST=localhost
DB_PORT=5433  # docker-compose.yml에 정의된 포트

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
```

### 2. 모바일 앱 테스트 시 주의사항
iOS 시뮬레이터나 실기기에서 로컬 서버에 접속하려면 서버가 모든 네트워크 인터페이스(`0.0.0.0`)에서 요청을 수신해야 합니다.
`src/index.js`에서 다음과 같이 설정되어 있는지 확인하세요:

```javascript
server.listen(PORT, '0.0.0.0', () => { ... });
```

또한 iOS 앱의 `AppConfig.swift`에서 `apiBaseURL`이 개발자 PC의 로컬 IP 주소(예: `192.168.x.x`)로 설정되어 있어야 합니다.

## 트러블슈팅 (Troubleshooting)

### Q. 서버 시작 시 `connect ETIMEDOUT` 에러가 발생합니다.
**A.** `DB_HOST`나 `REDIS_HOST`가 외부 IP로 설정되어 있는지 확인하세요. 로컬 개발 시에는 `localhost`여야 합니다.

### Q. 앱에서 API 요청 시 연결이 안 됩니다.
**A.** 다음을 확인하세요:
1. 서버가 `0.0.0.0`으로 바인딩되어 있는지 (`src/index.js`)
2. PC와 모바일 기기가 동일한 Wi-Fi 네트워크에 있는지
3. `AppConfig.swift`의 IP 주소가 현재 PC의 IP와 일치하는지 (`ifconfig`로 확인)

## API 문서

API 엔드포인트는 `architecture.md`의 API 설계 섹션을 참조하세요.





