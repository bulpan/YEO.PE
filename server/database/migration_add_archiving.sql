-- Archive Tables for Legal Compliance (6 Month Retention)

-- 1. Archived Rooms
CREATE TABLE IF NOT EXISTS yeope_schema.archived_rooms (
    id UUID PRIMARY KEY, -- Original ID preserved
    room_id VARCHAR(36),
    name VARCHAR(255),
    creator_id UUID,
    created_at TIMESTAMP,
    expires_at TIMESTAMP,
    metadata JSONB,
    archived_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_archived_rooms_archived_at ON yeope_schema.archived_rooms(archived_at);
CREATE INDEX IF NOT EXISTS idx_archived_rooms_creator_id ON yeope_schema.archived_rooms(creator_id);

-- 2. Archived Messages
CREATE TABLE IF NOT EXISTS yeope_schema.archived_messages (
    id UUID PRIMARY KEY, -- Original ID preserved
    room_id UUID,
    user_id UUID,
    type VARCHAR(50),
    content TEXT,
    image_url TEXT,
    created_at TIMESTAMP,
    expires_at TIMESTAMP,
    archived_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_archived_messages_archived_at ON yeope_schema.archived_messages(archived_at);
CREATE INDEX IF NOT EXISTS idx_archived_messages_user_id ON yeope_schema.archived_messages(user_id);
CREATE INDEX IF NOT EXISTS idx_archived_messages_room_id ON yeope_schema.archived_messages(room_id);

-- 3. Archived Room Members (Who was in the room)
CREATE TABLE IF NOT EXISTS yeope_schema.archived_room_members (
    id UUID PRIMARY KEY,
    room_id UUID,
    user_id UUID,
    joined_at TIMESTAMP,
    left_at TIMESTAMP,
    role VARCHAR(50),
    archived_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_archived_members_archived_at ON yeope_schema.archived_room_members(archived_at);
CREATE INDEX IF NOT EXISTS idx_archived_members_user_id ON yeope_schema.archived_room_members(user_id);
CREATE INDEX IF NOT EXISTS idx_archived_members_room_id ON yeope_schema.archived_room_members(room_id);
