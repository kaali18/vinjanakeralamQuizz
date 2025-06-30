# Stage 1: Build the Flutter web app
FROM cirrusci/flutter:3.22.2 AS build

# Set working directory
WORKDIR /app

# Copy project files
COPY . .

# Install dependencies and build the web app
RUN flutter pub get
RUN flutter build web --release

# Stage 2: Serve the web app with Nginx
FROM nginx:alpine

# Copy the built web assets from the build stage
COPY --from=build /app/build/web /usr/share/nginx/html

# Expose port 80
EXPOSE 80

# Start Nginx
CMD ["nginx", "-g", "daemon off;"]
