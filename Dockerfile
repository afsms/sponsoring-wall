# Build stage
FROM node:20-alpine AS build

WORKDIR /app

# Copy package files first for better layer caching
COPY package*.json ./

# Install dependencies (production + build tools)
RUN npm ci

# Copy source code
COPY . .

# Build-time environment variables (injected via docker-compose build args)
ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_ANON_KEY

ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL
ENV VITE_SUPABASE_ANON_KEY=$VITE_SUPABASE_ANON_KEY

# Build the application
RUN npm run build

# Production stage - minimal image
FROM nginx:stable-alpine

# Remove default nginx config
RUN rm -rf /etc/nginx/conf.d/*

# Copy the build output to Nginx's html directory
COPY --from=build /app/dist /usr/share/nginx/html

# Copy nginx configuration (overridden by volume mount in docker-compose)
COPY nginx.prod.conf /etc/nginx/conf.d/default.conf

# Non-root user for security
RUN chown -R nginx:nginx /usr/share/nginx/html && \
    chown -R nginx:nginx /var/cache/nginx && \
    chown -R nginx:nginx /var/log/nginx && \
    touch /var/run/nginx.pid && \
    chown -R nginx:nginx /var/run/nginx.pid

# Expose the port (Railway provides $PORT)
ENV PORT=80
EXPOSE 80

# Use a shell script to replace the port in the config and then start nginx
CMD ["/bin/sh", "-c", "sed -i \"s/listen 80;/listen ${PORT};/g\" /etc/nginx/conf.d/default.conf && nginx -g 'daemon off;'"]
