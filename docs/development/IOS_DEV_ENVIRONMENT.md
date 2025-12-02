# iOS 앱 개발을 위한 로컬 개발 환경 구성 가이드

이 문서는 iOS 앱 개발 시 필요한 백엔드(API) 서버를 로컬 Mac 환경에서 구동하고 연결하는 방법을 설명합니다.

## 1. 전체 구조도

```mermaid
graph TD
    subgraph Mac [Mac (개발용 PC)]
        subgraph Docker [Docker Containers]
            PG[PostgreSQL (5432)]
            Redis[Redis (6379)]
        end
        
        Node[Node.js Server (3000)]
        Node -->|localhost| PG
        Node -->|localhost| Redis
        
        Sim[iOS Simulator]
        Sim -->|http://localhost:3000| Node
    end
    
    subgraph iPhone [Physical iPhone]
        App[YEO.PE App]
        App -->|http://192.168.x.x:3000| Node
    end
    
    iPhone -.->|Wi-Fi| Mac
```

## 2. 사전 요구사항

*   **Docker Desktop**: 데이터베이스(PostgreSQL, Redis) 실행용
*   **Node.js (v18+)**: API 서버 실행용
*   **Git**: 소스 코드 관리

## 3. 단계별 설정 방법

### Step 1: 데이터베이스 실행 (Docker)

서버 코드가 있는 디렉토리(`server/`)에서 다음 명령어를 실행하여 DB와 Redis를 백그라운드에서 실행합니다.

```bash
cd server
docker-compose up -d
```

*   정상 실행 확인: `docker ps` 명령어로 `yeope-postgres`, `yeope-redis` 컨테이너가 떠 있는지 확인합니다.

### Step 2: 서버 환경 변수 설정

`server/.env` 파일을 생성하고 다음과 같이 설정합니다. (기본 `env.example` 복사)

```bash
cp .env.example .env
```

`.env` 파일 내용 확인 (로컬 개발용 기본값):
```ini
NODE_ENV=development
PORT=3000
DB_HOST=localhost
REDIS_HOST=localhost
# ... 나머지 설정 유지
```

### Step 3: 서버 실행

```bash
npm install  # 최초 1회 의존성 설치
npm run dev  # 개발 모드 실행 (코드 수정 시 자동 재시작)
```

터미널에 `🚀 YEO.PE Server is running on port 3000` 메시지가 뜨면 성공입니다.

## 4. iOS 앱 연결 방법 (Unified IP Strategy)

개발 편의성을 위해 **시뮬레이터와 실기기 모두 동일한 IP 주소**를 사용하여 접속하도록 설정합니다. 이렇게 하면 클라이언트 코드에서 환경에 따른 분기 처리를 줄일 수 있습니다.

*   **Target IP**: `192.168.219.113` (개발용 Mac의 고정 IP)

### 설정 방법

1.  **서버 설정 (`server/.env`)**
    *   외부 접속을 허용하기 위해 CORS 설정을 확인해주세요.
    *   `CORS_ORIGIN=*` 또는 `CORS_ORIGIN=http://192.168.219.113:3000`

2.  **iOS 앱 설정 (Client)**
    *   API Base URL을 다음과 같이 통일합니다.
    *   `http://192.168.219.113:3000`

3.  **접속 확인**
    *   **시뮬레이터**: Safari를 열고 `http://192.168.219.113:3000/health` 접속 확인
    *   **실기기**: 동일 Wi-Fi 연결 후 Safari에서 `http://192.168.219.113:3000/health` 접속 확인

> **⚠️ 주의사항**:
> *   Mac의 IP가 변경되면 앱 설정도 변경해야 합니다. (공유기 설정에서 Mac IP를 고정(DHCP Static Lease)해두면 편리합니다.)
> *   방화벽이 3000번 포트 접속을 차단하지 않도록 설정해주세요.

## 5. 문제 해결 (Troubleshooting)

*   **DB 연결 오류**: Docker가 실행 중인지 확인하세요 (`docker ps`).
*   **포트 충돌**: 이미 3000번 포트를 다른 프로세스가 사용 중이라면 `.env`에서 `PORT`를 3001 등으로 변경하고 앱에서도 포트를 맞춰주세요.
*   **실기기 접속 불가**: Mac과 아이폰이 같은 Wi-Fi인지 다시 확인하고, Mac의 방화벽 설정을 확인하세요.

---
**운영(Production) 환경과의 차이점**
*   운영 환경은 Oracle Cloud(OCI)에 배포되어 있으며, 도메인(`https://yeop3.com`)을 사용합니다.
*   앱 배포 시에는 Base URL을 운영 서버 주소로 변경해야 합니다.
