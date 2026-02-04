# 1. Fase de Construção (Build)
FROM debian:latest AS build-env

# Instala as dependências (Lista Atualizada e Simplificada)
RUN apt-get update && apt-get install -y \
    curl \
    git \
    wget \
    unzip \
    libglu1-mesa \
    fonts-droid-fallback \
    python3 \
    && apt-get clean

# Clona o Flutter
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter

# Configura o Path
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Habilita Web
RUN flutter channel stable
RUN flutter upgrade
RUN flutter config --enable-web

# Copia o projeto
RUN mkdir /app/
COPY . /app/
WORKDIR /app/

# Constrói o site
RUN flutter clean
RUN flutter pub get
RUN flutter build web --release

# 2. Fase de Servidor (Nginx)
FROM nginx:1.21.1-alpine
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Expõe a porta
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]