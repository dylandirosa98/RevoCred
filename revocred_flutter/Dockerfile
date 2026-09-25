FROM ubuntu:24.04 AS build

RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl git unzip xz-utils libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*
# Build from the verified SDK tag rather than a moving/unavailable third-party image.
RUN git clone --depth 1 --branch 3.44.9 https://github.com/flutter/flutter.git /opt/flutter \
    && test "$(git -C /opt/flutter rev-parse HEAD)" = "6b182d2c7585eba26d4edce0f97630effd256c33"
ENV PATH="/opt/flutter/bin:${PATH}"
RUN flutter config --no-analytics && flutter precache --web

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

ARG REVOCRED_USE_MOCKS=true
ARG REVOCRED_PRODUCTION=false
ARG REVOCRED_AUTH_REDIRECT_URL=
ARG REVOCRED_API_URL=
ARG SUPABASE_URL=
ARG SUPABASE_ANON_KEY=

RUN dart run tool/validate_build.dart

RUN flutter build web --release --no-web-resources-cdn \
    --dart-define=REVOCRED_PRODUCTION=${REVOCRED_PRODUCTION} \
    --dart-define=REVOCRED_AUTH_REDIRECT_URL=${REVOCRED_AUTH_REDIRECT_URL} \
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
