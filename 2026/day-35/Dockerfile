# Stage 1 — Build
FROM golang:1.22-alpine AS builder

WORKDIR /app
COPY app/ .
# Combine RUN commands → fewer layers
RUN go mod init hello && \
    go build -o hello .

# Stage 2 — Minimal runtime
FROM alpine:3.19

# Don't run as root
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup

WORKDIR /app
COPY --from=builder /app/hello .

# Switch to non-root user
USER appuser

CMD ["./hello"]