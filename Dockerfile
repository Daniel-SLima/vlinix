# 1. Fase de Construção (Build)
FROM debian:latest AS build-env

# Instala as dependências necessárias para o Flutter
RUN apt-get update && apt-get install -y curl git wget unzip libgconf-2-4 gdb libstdc++6 libglu1-mesa fonts-droid-fallback lib32stdc++6 python3
RUN apt-get clean

# Clona o Flutter (versão estável)
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter

# Coloca o flutter no caminho do sistema
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Habilita a web
RUN flutter channel stable
RUN flutter upgrade
RUN flutter config --enable-web

# Copia os arquivos do seu projeto para o container
RUN mkdir /app/
COPY . /app/
WORKDIR /app/

# Limpa e constrói o site (Web)
RUN flutter clean
RUN flutter pub get
RUN flutter build web --release

# 2. Fase de Servidor (Run) - Usando Nginx
FROM nginx:1.21.1-alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html

# O Railway injeta a porta na variável $PORT, mas o Nginx roda na 80 por padrão.
# O Railway sabe lidar com a porta 80 automaticamente.
EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]