# Stage 1: Build stage
FROM dart:stable AS build

WORKDIR /app

# Copy source code
COPY . .

# Get dependencies
RUN cd /app/inceptor_genesis_node && dart pub get && cd /app

# Compile Dart app thành native executable
RUN dart compile exe /app/inceptor_genesis_node/bin/inceptor_genesis_node.dart -o /app/inceptor_genesis_node/bin/inceptor_genesis_node

COPY ./inceptor_genesis_node/bin/assets /app/inceptor_genesis_node/bin/assets

# Stage 2: Runtime stage
# FROM debian:bullseye-slim
FROM mcr.microsoft.com/dotnet/aspnet:8.0-jammy

# Cài đặt các gói cần thiết (nếu app cần)
RUN apt-get update && apt-get install -y --no-install-recommends libstdc++6 && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy executable và thư mục cần thiết từ stage build
COPY --from=build /app/inceptor_genesis_node/bin /app

EXPOSE 80 
EXPOSE 443
EXPOSE 21213

# Nếu app cần config hoặc data khác thì copy thêm

# Chạy executable
CMD ["/app/inceptor_genesis_node"]
