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

- [프로젝트 기획서](./PROJECT_SPEC.md)
- [기술 설계서](./architecture.md)

## 🛠 기술 스택

### 클라이언트
- **iOS**: Swift, CoreBluetooth
- **Android**: Kotlin, Android BLE

### 서버
- **Backend**: Node.js, Express.js, Socket.io
- **Database**: PostgreSQL (Oracle Autonomous Database)
- **Cache**: Redis
- **Storage**: Oracle Cloud Object Storage

### 인프라
- **Cloud**: Oracle Cloud Infrastructure (OCI)
- **CI/CD**: GitHub Actions

## 🚀 시작하기

프로젝트는 현재 기획 및 설계 단계입니다.

## 📄 라이선스

이 프로젝트는 비공개 프로젝트입니다.

