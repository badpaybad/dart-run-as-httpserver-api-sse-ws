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

# docker build -f "dockerfile" -t dockerregistry.airobotics.vn/inceptor_genesis_node .
# docker push dockerregistry.airobotics.vn/inceptor_genesis_node
# docker pull dockerregistry.airobotics.vn/inceptor_genesis_node

#  sudo docker rm -f inceptor_genesis_node

# docker system prune -a -f
# docker volume prune -f
# docker builder prune -f

# sudo docker run -d --restart=always --name inceptor_genesis_node dockerregistry.airobotics.vn/inceptor_genesis_node

# docker logs -f inceptor_genesis_node
# docker system df
# sudo docker logs -f inceptor_genesis_node


# sudo docker exec -it inceptor_genesis_node /bin/bash
# sudo docker exec -it 5adc42619558 /bin/sh
# sudo docker logs -f airoboticscms
