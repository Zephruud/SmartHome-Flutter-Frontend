FROM ghcr.io/cirruslabs/flutter:stable AS build
WORKDIR /app
COPY . .
RUN flutter pub get
RUN flutter build web

FROM caddy:2-alpine
COPY --from=build /app/build/web /usr/share/caddy
EXPOSE 80