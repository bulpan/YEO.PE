-- BLE UID 테이블 추가 마이그레이션
-- 실행일: 2024-11

-- yeope 데이터베이스에 연결
\c yeope

-- 스키마 설정
SET search_path TO yeope_schema;

-- BLE UIDs 테이블 생성
CREATE TABLE IF NOT EXISTS ble_uids (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    uid VARCHAR(16) UNIQUE NOT NULL, -- Short UID (예: "A1B2C3D4")
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Active UID Constraint (User can have only one active UID)
CREATE UNIQUE INDEX IF NOT EXISTS unique_user_active_uid ON ble_uids(user_id) WHERE is_active = true;

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_ble_uids_uid ON ble_uids(uid);
CREATE INDEX IF NOT EXISTS idx_ble_uids_user_id ON ble_uids(user_id);
CREATE INDEX IF NOT EXISTS idx_ble_uids_expires_at ON ble_uids(expires_at);
CREATE INDEX IF NOT EXISTS idx_ble_uids_active ON ble_uids(uid, is_active) WHERE is_active = true;

-- 권한 부여
GRANT ALL PRIVILEGES ON TABLE ble_uids TO yeope_user;

-- 기존 활성 UID 비활성화 (필요시)
-- UPDATE ble_uids SET is_active = false WHERE expires_at < NOW();



