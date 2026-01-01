-- Push Tokens 테이블 생성
CREATE TABLE IF NOT EXISTS yeope_schema.push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES yeope_schema.users(id) ON DELETE CASCADE,
    device_token VARCHAR(500) NOT NULL, -- FCM/APNs 토큰
    platform VARCHAR(20) NOT NULL, -- 'ios' 또는 'android'
    device_id VARCHAR(255), -- 디바이스 고유 ID (선택)
    device_info JSONB, -- 디바이스 정보 (모델, OS 버전 등)
    is_active BOOLEAN DEFAULT true,
    last_used_at TIMESTAMP DEFAULT NOW(),
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT unique_user_device_token UNIQUE(user_id, device_token)
);

-- 인덱스 생성
CREATE INDEX IF NOT EXISTS idx_push_tokens_user_id ON yeope_schema.push_tokens(user_id);
CREATE INDEX IF NOT EXISTS idx_push_tokens_device_token ON yeope_schema.push_tokens(device_token);
CREATE INDEX IF NOT EXISTS idx_push_tokens_active ON yeope_schema.push_tokens(user_id, is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_push_tokens_platform ON yeope_schema.push_tokens(platform, is_active) WHERE is_active = true;

-- 권한 부여
GRANT ALL PRIVILEGES ON TABLE yeope_schema.push_tokens TO yeope_user;

-- updated_at 자동 업데이트 트리거 함수
CREATE OR REPLACE FUNCTION yeope_schema.update_push_tokens_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 트리거 생성
DROP TRIGGER IF EXISTS trigger_update_push_tokens_updated_at ON yeope_schema.push_tokens;
CREATE TRIGGER trigger_update_push_tokens_updated_at
    BEFORE UPDATE ON yeope_schema.push_tokens
    FOR EACH ROW
    EXECUTE FUNCTION yeope_schema.update_push_tokens_updated_at();



