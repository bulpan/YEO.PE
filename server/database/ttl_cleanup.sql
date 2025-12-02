-- TTL 자동 삭제 함수 및 스케줄러 설정
-- pg_cron 확장이 설치되어 있어야 함

-- 만료된 방 삭제 함수
CREATE OR REPLACE FUNCTION cleanup_expired_rooms()
RETURNS void AS $$
BEGIN
    -- 만료된 방의 메시지 삭제
    DELETE FROM yeope_schema.messages
    WHERE expires_at < NOW();
    
    -- 만료된 방의 멤버 삭제
    DELETE FROM yeope_schema.room_members
    WHERE room_id IN (
        SELECT id FROM yeope_schema.rooms WHERE expires_at < NOW()
    );
    
    -- 만료된 방 삭제
    DELETE FROM yeope_schema.rooms
    WHERE expires_at < NOW();
    
    RAISE NOTICE 'Expired rooms and messages cleaned up at %', NOW();
END;
$$ LANGUAGE plpgsql;

-- pg_cron으로 매 시간마다 실행 (pg_cron이 설치된 경우)
-- SELECT cron.schedule('cleanup-expired-rooms', '0 * * * *', 'SELECT cleanup_expired_rooms()');





