FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm install --only=production

# Final stage
FROM node:20-alpine

RUN apk add --no-cache \
    chromium \
    nss \
    harfbuzz \
    ca-certificates \
    ttf-freefont

WORKDIR /app

# Copy node_modules
COPY --from=builder /app/node_modules ./node_modules

# Copy application code
COPY . .

# Create directories
RUN mkdir -p logs

# Set environment variables
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true

EXPOSE 3000

CMD ["npm", "start"]
