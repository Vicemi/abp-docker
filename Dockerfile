# Etapa base para el contenedor de runtime
FROM mcr.microsoft.com/dotnet/aspnet:8.0 AS base
WORKDIR /app
EXPOSE 80
EXPOSE 443

ENV ASPNETCORE_URLS=http://+:80;https://+:443

# Etapa build para compilar la aplicación
FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Instalación de Node.js (v20) y Yarn más reciente
ENV NODE_VERSION 20.8.0
ENV YARN_VERSION 1.22.19

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get update \
    && apt-get install -y nodejs \
    && npm install -g yarn@$YARN_VERSION

# Copiar todos los proyectos en la estructura correcta
COPY ["src/Acme.BookStore.Web/Acme.BookStore.Web.csproj", "src/Acme.BookStore.Web/"]
COPY ["src/Acme.BookStore.Application/Acme.BookStore.Application.csproj", "src/Acme.BookStore.Application/"]
COPY ["src/Acme.BookStore.HttpApi/Acme.BookStore.HttpApi.csproj", "src/Acme.BookStore.HttpApi/"]
COPY ["src/Acme.BookStore.EntityFrameworkCore/Acme.BookStore.EntityFrameworkCore.csproj", "src/Acme.BookStore.EntityFrameworkCore/"]
COPY ["src/Acme.BookStore.Domain/Acme.BookStore.Domain.csproj", "src/Acme.BookStore.Domain/"]
COPY ["src/Acme.BookStore.Domain.Shared/Acme.BookStore.Domain.Shared.csproj", "src/Acme.BookStore.Domain.Shared/"]
RUN dotnet restore "src/Acme.BookStore.Web/Acme.BookStore.Web.csproj"

# Copiar el resto del código
COPY . . 
WORKDIR "/src/Acme.BookStore.Web"

# Instalar las dependencias de ABP (usando una versión específica)
RUN dotnet tool install -g Volo.Abp.Cli --version 4.4.0 \
    && export PATH="$PATH:/root/.dotnet/tools" \
    && abp install-libs

# Instalar dependencias de Node.js usando Yarn
RUN yarn install --frozen-lockfile

# Construir la aplicación
RUN dotnet build "Acme.BookStore.Web.csproj" -c Release -o /app/build

# Etapa publish para preparar la salida final
FROM build AS publish
RUN dotnet publish "Acme.BookStore.Web.csproj" -c Release -o /app/publish /p:UseAppHost=false

# Etapa final: runtime
FROM base AS final
WORKDIR /app
COPY --from=publish /app/publish .
ENTRYPOINT ["dotnet", "Acme.BookStore.Web.dll"]
