#!/usr/bin/env bash
# 오운 API 서버 배포 — GHCR의 최신 이미지를 받아 컨테이너를 교체한다.
#
# 서버에서 .env와 같은 디렉터리에 두고 실행: ./deploy.sh
# GHCR 패키지가 비공개면 미리 로그인이 필요하다:
#   echo <PAT> | docker login ghcr.io -u dduneon --password-stdin
set -euo pipefail

IMAGE="ghcr.io/dduneon/oun/backend:latest"
NAME="oun-backend"
NETWORK="service-net"
PORT=4030

cd "$(dirname "$0")"

if [ ! -f .env ]; then
  echo "이 디렉터리에 .env가 없습니다: $(pwd)" >&2
  exit 1
fi

docker pull "$IMAGE"

# DB 스키마를 먼저 반영한다. 여기서 실패하면 스크립트가 멈추고,
# 기존 컨테이너는 그대로 살아있다(깨진 스키마로 새 버전이 뜨는 걸 막는다).
echo "== 마이그레이션 =="
docker run --rm \
  --network "$NETWORK" \
  --env-file .env \
  "$IMAGE" ./node_modules/.bin/prisma migrate deploy

echo "== 컨테이너 교체 =="
docker stop "$NAME" 2>/dev/null || true
docker rm "$NAME" 2>/dev/null || true

# 혹시 같은 포트를 점유 중인 다른 컨테이너가 있으면 정리
docker ps -q --filter "publish=$PORT" | xargs -r docker stop
docker ps -aq --filter "publish=$PORT" | xargs -r docker rm

# -e PORT는 --env-file 뒤에 와서 .env 값을 덮어쓴다.
# 앱이 컨테이너 안에서도 $PORT로 듣게 해 포트 매핑을 1:1로 맞춘다.
docker run -d \
  --name "$NAME" \
  --network "$NETWORK" \
  --restart unless-stopped \
  -p "$PORT:$PORT" \
  --env-file .env \
  -e PORT="$PORT" \
  "$IMAGE"

echo "== 기동 확인 =="
for _ in $(seq 1 30); do
  if curl -fsS "http://localhost:$PORT/health" >/dev/null 2>&1; then
    echo "정상: http://localhost:$PORT/health"
    docker image prune -f >/dev/null 2>&1 || true # 교체로 떠버린 이전 이미지 정리
    exit 0
  fi
  sleep 1
done

echo "30초 안에 응답이 없습니다. 최근 로그:" >&2
docker logs --tail 50 "$NAME" >&2
exit 1
