# YEO.PE 문서 가이드

이 폴더는 YEO.PE 프로젝트의 모든 문서를 체계적으로 관리합니다.

## 📁 폴더 구조

```
docs/
├── README.md                    # 이 파일 (문서 가이드)
├── planning/                    # 기획 및 요구사항
│   └── PROJECT_SPEC.md         # 프로젝트 기획서
├── architecture/                # 기술 설계
│   └── architecture.md         # 기술 아키텍처 설계서
├── functional-spec/             # 기능 명세서
│   ├── FUNCTIONAL_SPEC.md      # 기능 명세서 메인 (목차)
│   ├── 01-authentication.md    # 사용자 인증
│   ├── 02-room-management.md   # 방 관리
│   ├── 03-realtime-chat.md     # 실시간 채팅
│   ├── 04-ble-discovery.md     # BLE 탐색
│   ├── 05-file-upload.md       # 파일 업로드
│   ├── 06-push-notification.md # 푸시 알림
│   ├── 07-user-profile.md      # 사용자 프로필
│   └── 08-ttl-management.md    # TTL 자동 정리
└── development/                 # 개발 가이드 및 검토
    ├── IMPLEMENTATION_GUIDE.md # 구현 가이드
    └── DOCUMENT_REVIEW.md      # 문서 검토 결과
```

## 📚 문서 읽기 순서

### 1. 프로젝트 이해
1. [프로젝트 루트 README.md](../README.md) - 프로젝트 개요
2. [기획서](./planning/PROJECT_SPEC.md) - 서비스 기획 및 요구사항

### 2. 기술 설계 이해
3. [기술 아키텍처](./architecture/architecture.md) - 시스템 설계

### 3. 기능 구현
4. [기능 명세서 메인](./functional-spec/FUNCTIONAL_SPEC.md) - 기능 목록
5. [기능별 상세 명세](./functional-spec/) - 각 기능의 상세 명세

### 4. 개발 시작
6. [구현 가이드](./development/IMPLEMENTATION_GUIDE.md) - 누락된 기능 구현
7. [문서 검토 결과](./development/DOCUMENT_REVIEW.md) - 일관성 검토

## 🎯 문서별 용도

### 기획 문서 (`planning/`)
- **대상**: 기획자, PM, 이해관계자
- **용도**: 서비스 기획, 요구사항 확인
- **내용**: 서비스 개요, 기능 목록, 사용자 흐름, 정책

### 기술 설계 (`architecture/`)
- **대상**: 개발자, 아키텍트
- **용도**: 시스템 설계, 기술 스택 결정
- **내용**: 아키텍처, DB 스키마, API 설계, 보안

### 기능 명세 (`functional-spec/`)
- **대상**: 개발자, QA
- **용도**: 기능 구현, 테스트 케이스 작성
- **내용**: 각 기능의 상세 동작, API 명세, 테스트 케이스

### 개발 가이드 (`development/`)
- **대상**: 개발자
- **용도**: 실제 구현 가이드, 문제 해결
- **내용**: 구현 방법, 마이그레이션, 검토 결과

## 📝 문서 업데이트 규칙

1. **기획 변경 시**: `planning/PROJECT_SPEC.md` 먼저 업데이트
2. **기술 변경 시**: `architecture/architecture.md` 업데이트
3. **기능 추가/변경 시**: `functional-spec/` 해당 문서 업데이트
4. **구현 완료 시**: `development/` 가이드 업데이트

## 🔗 빠른 링크

- [프로젝트 루트](../README.md)
- [기획서](./planning/PROJECT_SPEC.md)
- [기술 설계서](./architecture/architecture.md)
- [기능 명세서](./functional-spec/FUNCTIONAL_SPEC.md)



