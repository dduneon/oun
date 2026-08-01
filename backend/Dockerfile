# 오운 API 서버 이미지 (NestJS + Prisma)
#
# 빌드 단계에서 Prisma 클라이언트를 생성하고 Nest를 컴파일한 뒤,
# 런타임 단계에는 운영 의존성 + 생성된 클라이언트 + dist만 남긴다.
# 두 단계 모두 alpine이라 Prisma 엔진 바이너리(musl)가 그대로 맞는다.

# ── 1) 빌드 ──────────────────────────────────────────────
FROM node:22-alpine AS build
WORKDIR /app

# 락파일 기준 설치 — 소스가 바뀌어도 이 레이어는 캐시된다.
COPY package.json package-lock.json ./
COPY prisma ./prisma
RUN npm ci

COPY . .
RUN npx prisma generate && npm run build

# ── 2) 런타임 ────────────────────────────────────────────
FROM node:22-alpine AS runtime
WORKDIR /app
ENV NODE_ENV=production

# Prisma 쿼리 엔진이 요구하는 OpenSSL.
RUN apk add --no-cache openssl

COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force

# 생성된 Prisma 클라이언트와, 배포 시 `prisma migrate deploy`를 돌릴 CLI.
# (prisma CLI는 devDependency라 --omit=dev 설치에는 들어오지 않는다)
COPY --from=build /app/node_modules/.prisma ./node_modules/.prisma
COPY --from=build /app/node_modules/@prisma ./node_modules/@prisma
COPY --from=build /app/node_modules/prisma ./node_modules/prisma
COPY --from=build /app/node_modules/.bin/prisma ./node_modules/.bin/prisma

COPY --from=build /app/dist ./dist
COPY prisma ./prisma

EXPOSE 3000
USER node
CMD ["node", "dist/main"]
