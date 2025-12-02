# YEO.PE

블루투스 기반 휘발성 근거리 채팅 서비스

## 📱 프로젝트 소개

YEO.PE는 GPS 없이 **블루투스 신호(BLE)**를 이용해 실제 가까이 있는 사람들과 가볍게 연결하고, 휘발성 그룹채팅을 즐길 수 있는 **근거리 SNS** 서비스입니다.

> "지도 밖에서 만나는 진짜 연결, YEO.PE."

## 🎯 핵심 기능

- BLE 근거리 사용자 탐색
- 휘발성 채팅방 (24시간 TTL)
- 실시간 그룹 채팅 (텍스트, 이미지, 이모지)
- 회원/비회원 모드
- 익명성 보장 (닉네임 마스킹)

## 📚 문서

자세한 문서는 [`docs/`](./docs/) 폴더를 참조하세요.

- [📖 문서 가이드](./docs/README.md) - 문서 구조 및 읽기 순서
- [📋 프로젝트 기획서](./docs/planning/PROJECT_SPEC.md) - 서비스 기획 및 요구사항
- [🏗️ 기술 설계서](./docs/architecture/architecture.md) - 시스템 아키텍처
- [📝 기능 명세서](./docs/functional-spec/FUNCTIONAL_SPEC.md) - 기능별 상세 명세
- [🛠️ 개발 가이드](./docs/development/IMPLEMENTATION_GUIDE.md) - 구현 가이드

## 🛠 기술 스택

### 클라이언트
- **iOS**: Swift, CoreBluetooth
- **Android**: Kotlin, Android BLE

### 서버
- **Backend**: Node.js, Express.js, Socket.io ✅
- **Database**: PostgreSQL 13+ (Oracle Cloud VM) ✅
- **Cache**: Redis 6+ ✅
- **Storage**: Oracle Cloud Object Storage (예정)
- **Web Server**: Nginx (리버스 프록시) ✅

### 인프라
- **Cloud**: Oracle Cloud Infrastructure (OCI) ✅
- **Domain**: yeop3.com (Cloudflare DNS) ✅
- **CI/CD**: GitHub Actions (예정)

## 🚀 시작하기

### 현재 상태

**✅ 완료된 작업 (MVP Phase 1-6)**
- ✅ 프로젝트 기본 구조 설정
- ✅ PostgreSQL 데이터베이스 설정 및 스키마 생성
- ✅ Node.js 서버 기본 설정 (Express.js, Socket.io)
- ✅ 사용자 인증 시스템 (JWT, 이메일 회원가입/로그인)
- ✅ 방 관리 API (생성, 조회, 참여, 나가기)
- ✅ 실시간 채팅 구현 (WebSocket, Socket.io)
- ✅ TTL 자동 정리 시스템 (24시간 만료)
- ✅ 서버 배포 (Oracle Cloud Infrastructure)
- ✅ 도메인 설정 (yeop3.com, Nginx 리버스 프록시)

**🚧 진행 중**
- 모바일 앱 개발 (iOS/Android)
- 이미지 업로드 기능
- 푸시 알림 연동

### 서버 접속 정보

- **도메인**: https://yeop3.com
- **API 엔드포인트**: https://yeop3.com/api
- **Health Check**: https://yeop3.com/health
- **서버 IP**: 152.67.208.177
- **인프라**: Oracle Cloud Infrastructure (Free Tier)

### 로컬 개발 환경 설정

#### 1. 필수 요구사항
- Node.js 18.x 이상
- PostgreSQL 13 이상
- Redis 6 이상

#### 2. 서버 설정

```bash
# 저장소 클론
git clone https://github.com/YOUR_USERNAME/YEO.PE.git
cd YEO.PE/server

# 의존성 설치
npm install

# 환경 변수 설정
cp .env.example .env
# .env 파일을 편집하여 데이터베이스 및 기타 설정 입력

# 데이터베이스 초기화
psql -U postgres -f database/init.sql

# 개발 서버 실행
npm run dev
```

서버가 `http://localhost:3000`에서 실행됩니다.

#### 3. 테스트

```bash
# 단위 테스트
npm test

# API 테스트
curl http://localhost:3000/health
```

### 프로덕션 배포

현재 프로덕션 서버는 Oracle Cloud Infrastructure에 배포되어 있습니다.

- **서버 위치**: `/opt/yeope/server`
- **프로세스 관리**: Node.js 직접 실행 (PM2 설정 예정)
- **리버스 프록시**: Nginx (포트 80, 443)
- **도메인**: yeop3.com (Cloudflare DNS)

### API 문서

자세한 API 문서는 [기술 설계서](./docs/architecture/architecture.md)의 API 설계 섹션과 [기능 명세서](./docs/functional-spec/FUNCTIONAL_SPEC.md)를 참조하세요.

### 테스트

- **API 테스트**: `server/tests/manual-test.md` 참조
- **WebSocket 테스트**: `server/tests/websocket-test.html` 또는 `server/tests/websocket-client.js` 사용

## 📄 라이선스

이 프로젝트는 비공개 프로젝트입니다.

