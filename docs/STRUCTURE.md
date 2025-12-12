# 문서 구조 개요

## 📁 폴더 구조

```
YEO.PE/
├── README.md                    # 프로젝트 루트 README
├── docs/                        # 📚 모든 문서
│   ├── README.md               # 문서 가이드 (이 폴더 안내)
│   │
│   ├── planning/               # 📋 기획 및 요구사항
│   │   └── PROJECT_SPEC.md    # 프로젝트 기획서
│   │
│   ├── architecture/           # 🏗️ 기술 설계
│   │   └── architecture.md    # 기술 아키텍처 설계서
│   │
│   ├── functional-spec/        # 📝 기능 명세서
│   │   ├── FUNCTIONAL_SPEC.md # 기능 명세서 메인 (목차)
│   │   ├── 01-authentication.md
│   │   ├── 02-room-management.md
│   │   ├── 03-realtime-chat.md
│   │   ├── 04-ble-discovery.md
│   │   ├── 05-file-upload.md
│   │   ├── 06-push-notification.md
│   │   ├── 07-user-profile.md
│   │   ├── 08-ttl-management.md
│   │   └── 09-user-safety.md  # ✅ 신고/차단
│   │
│   ├── design_system.md       # 🎨 디자인 시스템
│   └── development/            # 🛠️ 개발 가이드
│       ├── IMPLEMENTATION_GUIDE.md  # 구현 가이드
│       └── DOCUMENT_REVIEW.md       # 문서 검토 결과
│
└── server/                      # 서버 코드
    ├── database/               # DB 스키마 및 마이그레이션
    └── ...
```

## 📖 문서 분류 기준

### planning/ (기획)
- **대상**: 기획자, PM, 이해관계자
- **내용**: 서비스 기획, 요구사항, 사용자 흐름, 정책
- **파일**: `PROJECT_SPEC.md`

### architecture/ (기술 설계)
- **대상**: 개발자, 아키텍트
- **내용**: 시스템 아키텍처, 기술 스택, DB 스키마, API 설계
- **파일**: `architecture.md`

### functional-spec/ (기능 명세)
- **대상**: 개발자, QA
- **내용**: 각 기능의 상세 동작, API 명세, 테스트 케이스
- **파일**: `FUNCTIONAL_SPEC.md` (목차) + 기능별 상세 문서

### development/ (개발 가이드)
- **대상**: 개발자
- **내용**: 구현 방법, 마이그레이션, 검토 결과, 문제 해결
- **파일**: `IMPLEMENTATION_GUIDE.md`, `DOCUMENT_REVIEW.md`

## 🔗 문서 간 참조 관계

```
README.md (루트)
  └─> docs/README.md
       ├─> planning/PROJECT_SPEC.md
       ├─> architecture/architecture.md
       ├─> functional-spec/FUNCTIONAL_SPEC.md
       └─> development/IMPLEMENTATION_GUIDE.md

FUNCTIONAL_SPEC.md
  ├─> planning/PROJECT_SPEC.md
  ├─> architecture/architecture.md
  └─> 기능별 상세 문서들

기능별 상세 문서
  └─> architecture/architecture.md (API/DB 참조)
