FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG REVOCRED_USE_MOCKS=true
ARG REVOCRED_API_URL=
ARG SUPABASE_URL=
ARG SUPABASE_ANON_KEY=

RUN flutter build web --release --no-web-resources-cdn \
    --dart-define=REVOCRED_USE_MOCKS=${REVOCRED_USE_MOCKS} \
    --dart-define=REVOCRED_API_URL=${REVOCRED_API_URL} \
    --dart-define=SUPABASE_URL=${SUPABASE_URL} \
    --dart-define=SUPABASE_ANON_KEY=${SUPABASE_ANON_KEY}

FROM nginx:1.29-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget -q --spider http://127.0.0.1/healthz || exit 1
