-- BLE UIDs 테이블 생성
CREATE TABLE IF NOT EXISTS yeope_schema.ble_uids (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES yeope_schema.users(id) ON DELETE CASCADE,
    uid VARCHAR(16) UNIQUE NOT NULL, -- Short UID (예: "A1B2C3D4")
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    is_active BOOLEAN DEFAULT true
);

-- Active UID Constraint (User can have only one active UID)
CREATE UNIQUE INDEX IF NOT EXISTS unique_user_active_uid ON yeope_schema.ble_uids(user_id) WHERE is_active = true;

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_ble_uids_uid ON yeope_schema.ble_uids(uid);
CREATE INDEX IF NOT EXISTS idx_ble_uids_user_id ON yeope_schema.ble_uids(user_id);
CREATE INDEX IF NOT EXISTS idx_ble_uids_expires_at ON yeope_schema.ble_uids(expires_at);
CREATE INDEX IF NOT EXISTS idx_ble_uids_active ON yeope_schema.ble_uids(uid, is_active) WHERE is_active = true;

-- 권한 부여
GRANT ALL PRIVILEGES ON TABLE yeope_schema.ble_uids TO yeope_user;



