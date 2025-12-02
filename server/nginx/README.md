# Nginx 설정 가이드

## 현재 설정

- **도메인**: yeop3.com
- **Nginx**: 리버스 프록시 (포트 80, 443)
- **Node.js 서버**: localhost:3000
- **SSL**: 임시 자체 서명 인증서 (Cloudflare Flexible 모드)

## Cloudflare 설정

### 1. SSL/TLS 모드 설정

Cloudflare 대시보드에서:
1. **SSL/TLS** → **Overview** 메뉴로 이동
2. **SSL/TLS encryption mode**를 **Flexible**로 설정
   - Flexible: Cloudflare ↔ 사용자 (HTTPS), Cloudflare ↔ Origin (HTTP)
   - 현재 자체 서명 인증서를 사용 중이므로 Flexible 모드 권장

### 2. DNS 설정 확인

- **A 레코드**: `yeop3.com` → `152.67.208.177` (프록시 활성화)
- **A 레코드**: `www.yeop3.com` → `152.67.208.177` (프록시 활성화)

## Let's Encrypt 인증서 발급 (선택사항)

Full 모드로 전환하려면 Let's Encrypt 인증서를 발급받아야 합니다.

### 1. Certbot 설치

```bash
sudo dnf install -y certbot python3-certbot-nginx
```

### 2. 인증서 발급

```bash
sudo certbot --nginx -d yeop3.com -d www.yeop3.com
```

### 3. 자동 갱신 설정

```bash
sudo certbot renew --dry-run
```

인증서는 90일마다 자동 갱신됩니다.

### 4. Nginx 설정 업데이트

인증서 발급 후 `/etc/nginx/conf.d/yeop3.com.conf` 파일의 SSL 인증서 경로가 자동으로 업데이트됩니다:

```nginx
ssl_certificate /etc/letsencrypt/live/yeop3.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/yeop3.com/privkey.pem;
```

### 5. Cloudflare 모드 변경

Let's Encrypt 인증서 발급 후:
1. Cloudflare 대시보드에서 **SSL/TLS encryption mode**를 **Full**로 변경
2. 이제 Cloudflare ↔ Origin도 HTTPS로 통신합니다.

## 테스트

### HTTP 테스트
```bash
curl http://yeop3.com/health
```

### HTTPS 테스트
```bash
curl https://yeop3.com/health
```

### API 테스트
```bash
curl http://yeop3.com/api/rooms/nearby
```

## 문제 해결

### Nginx가 시작되지 않는 경우

```bash
# 설정 파일 문법 확인
sudo nginx -t

# 에러 로그 확인
sudo journalctl -xeu nginx.service

# 직접 실행하여 에러 확인
sudo nginx
```

### 521 에러 (Cloudflare)

- Origin 서버에 연결할 수 없음
- Nginx가 실행 중인지 확인: `sudo systemctl status nginx`
- 포트 80, 443이 열려있는지 확인: `sudo firewall-cmd --list-all`

### SSL 인증서 오류

- 자체 서명 인증서는 브라우저에서 경고가 표시됩니다 (정상)
- Cloudflare Flexible 모드를 사용하면 사용자는 HTTPS로 접속하지만, Origin은 HTTP로 통신합니다
- Let's Encrypt 인증서를 발급받으면 Full 모드로 전환 가능합니다

## WebSocket 지원

Nginx 설정에 WebSocket 지원이 포함되어 있습니다:
- `/socket.io/` 경로는 WebSocket 업그레이드 지원
- 타임아웃 설정: 7일 (장기 연결 지원)

## 보안 헤더

다음 보안 헤더가 설정되어 있습니다:
- `X-Frame-Options: SAMEORIGIN`
- `X-Content-Type-Options: nosniff`
- `X-XSS-Protection: 1; mode=block`





