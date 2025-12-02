-- YEO.PE 데이터베이스 초기화 스크립트

-- 데이터베이스 생성
CREATE DATABASE yeope;

-- 사용자 생성
CREATE USER yeope_user WITH PASSWORD 'yeope_password_2024';

-- 권한 부여
GRANT ALL PRIVILEGES ON DATABASE yeope TO yeope_user;

-- yeope 데이터베이스에 연결
\c yeope

-- 스키마 생성
CREATE SCHEMA IF NOT EXISTS yeope_schema;
SET search_path TO yeope_schema;

-- Users 테이블
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    auth_provider VARCHAR(50) NOT NULL, -- 'email', 'google', 'apple'
    provider_id VARCHAR(255),
    nickname VARCHAR(100) NOT NULL,
    nickname_mask VARCHAR(100) NOT NULL,
    password_hash VARCHAR(255), -- 이메일 로그인 시에만 사용
    created_at TIMESTAMP DEFAULT NOW(),
    last_login_at TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    settings JSONB DEFAULT '{"bleVisible": true, "pushEnabled": true}'::jsonb,
    CONSTRAINT unique_provider_id UNIQUE(auth_provider, provider_id)
);

-- 인덱스 생성
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_created_at ON users(created_at);
CREATE INDEX idx_users_provider ON users(auth_provider, provider_id);

-- Rooms 테이블
CREATE TABLE rooms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id VARCHAR(36) UNIQUE NOT NULL, -- UUID 문자열
    name VARCHAR(255) NOT NULL,
    creator_id UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    member_count INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT true,
    metadata JSONB DEFAULT '{"category": "general"}'::jsonb
);

-- 인덱스 생성
CREATE INDEX idx_rooms_room_id ON rooms(room_id);
CREATE INDEX idx_rooms_expires_at ON rooms(expires_at);
CREATE INDEX idx_rooms_created_at ON rooms(created_at);
CREATE INDEX idx_rooms_creator_id ON rooms(creator_id);
CREATE INDEX idx_rooms_active ON rooms(is_active, expires_at) WHERE is_active = true;

-- Messages 테이블
CREATE TABLE messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    type VARCHAR(50) NOT NULL, -- 'text', 'image', 'emoji'
    content TEXT, -- 암호화된 메시지
    encrypted_content TEXT, -- AES-256 암호화된 원본
    image_url TEXT, -- Object Storage 이미지 URL
    created_at TIMESTAMP DEFAULT NOW(),
    expires_at TIMESTAMP NOT NULL,
    is_deleted BOOLEAN DEFAULT false
);

-- 인덱스 생성
CREATE INDEX idx_messages_room_created ON messages(room_id, created_at DESC);
CREATE INDEX idx_messages_expires_at ON messages(expires_at);
CREATE INDEX idx_messages_user_id ON messages(user_id);
CREATE INDEX idx_messages_room_active ON messages(room_id, created_at DESC) WHERE is_deleted = false;

-- RoomMembers 테이블 (참여자 관리)
CREATE TABLE room_members (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    room_id UUID REFERENCES rooms(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    joined_at TIMESTAMP DEFAULT NOW(),
    left_at TIMESTAMP,
    role VARCHAR(50) DEFAULT 'member', -- 'member', 'creator'
    last_seen_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT unique_room_user_active UNIQUE(room_id, user_id, left_at)
);

-- 인덱스 생성
CREATE INDEX idx_room_members_room_user ON room_members(room_id, user_id);
CREATE INDEX idx_room_members_user_active ON room_members(user_id, left_at) WHERE left_at IS NULL;
CREATE INDEX idx_room_members_room_active ON room_members(room_id, left_at) WHERE left_at IS NULL;

-- 권한 부여
GRANT ALL PRIVILEGES ON SCHEMA yeope_schema TO yeope_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA yeope_schema TO yeope_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA yeope_schema TO yeope_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA yeope_schema GRANT ALL ON TABLES TO yeope_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA yeope_schema GRANT ALL ON SEQUENCES TO yeope_user;





