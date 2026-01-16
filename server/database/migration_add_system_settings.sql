CREATE TABLE IF NOT EXISTS yeope_schema.system_settings (
    key VARCHAR(255) PRIMARY KEY,
    value TEXT,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert defaults if not exist
INSERT INTO yeope_schema.system_settings (key, value) VALUES
('suspension_duration_hours', '24'),
('suspension_reason', '커뮤니티 가이드라인 위반으로 인해 일시 정지되었습니다.'),
('ban_reason', '운영 정책 위반으로 인해 계정이 영구 정지되었습니다.')
ON CONFLICT (key) DO NOTHING;
