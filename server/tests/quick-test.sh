#!/bin/bash

# 빠른 API 테스트 스크립트
# 사용법: ./tests/quick-test.sh

BASE_URL="http://localhost:3000"
TOKEN=""
ROOM_ID=""

echo "🧪 YEO.PE API 빠른 테스트"
echo "=========================="
echo ""

# 1. Health Check
echo "1️⃣ Health Check..."
curl -s "$BASE_URL/health" | jq .
echo ""

# 2. 회원가입
echo "2️⃣ 회원가입..."
REGISTER_RESPONSE=$(curl -s -X POST "$BASE_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test'$(date +%s)'@example.com",
    "password": "testpassword123",
    "nickname": "테스트유저"
  }')

TOKEN=$(echo $REGISTER_RESPONSE | jq -r '.token')
echo "토큰: ${TOKEN:0:50}..."
echo ""

# 3. 현재 사용자 정보
echo "3️⃣ 현재 사용자 정보..."
curl -s "$BASE_URL/api/auth/me" \
  -H "Authorization: Bearer $TOKEN" | jq .
echo ""

# 4. 방 생성
echo "4️⃣ 방 생성..."
ROOM_RESPONSE=$(curl -s -X POST "$BASE_URL/api/rooms" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "name": "테스트 방",
    "category": "general"
  }')

ROOM_ID=$(echo $ROOM_RESPONSE | jq -r '.roomId')
echo "방 ID: $ROOM_ID"
echo ""

# 5. 근처 방 목록
echo "5️⃣ 근처 방 목록..."
curl -s "$BASE_URL/api/rooms/nearby" | jq '.rooms | length'
echo ""

# 6. 방 상세 정보
echo "6️⃣ 방 상세 정보..."
curl -s "$BASE_URL/api/rooms/$ROOM_ID" | jq .
echo ""

# 7. 메시지 전송
echo "7️⃣ 메시지 전송..."
curl -s -X POST "$BASE_URL/api/rooms/$ROOM_ID/messages" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "type": "text",
    "content": "테스트 메시지입니다!"
  }' | jq .
echo ""

# 8. 메시지 목록
echo "8️⃣ 메시지 목록..."
curl -s "$BASE_URL/api/rooms/$ROOM_ID/messages" | jq '.messages | length'
echo ""

echo "✅ 테스트 완료!"





