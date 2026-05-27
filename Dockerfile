# build frontend
FROM node:22-alpine AS node-builder
COPY . /app
WORKDIR /app

# force development mode inside the container stage
ENV NODE_ENV=development

# bypass the Tiptap version mismatch
RUN npm install --legacy-peer-deps

RUN npx svelte-kit sync
RUN npx vite --config common.config.js build
RUN npx vite --config app.config.js build

# build backend
FROM golang:1.25-alpine AS go-builder
RUN apk add --no-short-logs --no-cache gcc musl-dev
COPY . /app
WORKDIR /app
COPY --from=node-builder /app/build /app/build
RUN go mod download
RUN CGO_ENABLED=1 GOOS=linux go build -ldflags="-s -w" -tags production -o primo main.go

# Production image
FROM alpine:3 AS runtime
RUN apk add --no-short-logs --no-cache tzdata
WORKDIR /app
COPY --from=go-builder /app/primo /app/primo

ENV APP_ENV=production
ENV PORT=8080
EXPOSE 8080

CMD ["/app/primo", "serve", "--http=0.0.0.0:8080"]