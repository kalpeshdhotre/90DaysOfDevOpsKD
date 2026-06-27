# ─── Stage 1: Build / install dependencies ───────────────────────────────────
FROM node:20-alpine AS builder

# Set working directory
WORKDIR /app

# Copy only package files first (layer cache optimization)
COPY package*.json ./

# Install only production dependencies
RUN npm ci --omit=dev

# ─── Stage 2: Final runtime image ─────────────────────────────────────────────
FROM node:20-alpine AS runner

# Create a non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

WORKDIR /app

# Copy installed node_modules from builder stage
COPY --from=builder /app/node_modules ./node_modules

# Copy app source code
COPY server.js .

# Change ownership to non-root user
RUN chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Expose app port
EXPOSE 3000

# Health check for the app container
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

# Start the server
CMD ["node", "server.js"]