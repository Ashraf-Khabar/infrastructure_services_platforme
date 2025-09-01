FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src

# Copie le .csproj du Client
COPY ["UserManagement.Client/UserManagement.Client.csproj", "UserManagement.Client/"]
RUN dotnet restore "UserManagement.Client/UserManagement.Client.csproj"

# Copie tout le projet
COPY . .

WORKDIR "/src/UserManagement.Client"
RUN dotnet build "UserManagement.Client.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "UserManagement.Client.csproj" -c Release -o /app/publish

FROM nginx:alpine AS final
WORKDIR /usr/share/nginx/html

# Copie les fichiers publiés du Client
COPY --from=publish /app/publish/wwwroot .

# Copie la configuration nginx depuis le dossier nginx-config
COPY nginx-config/nginx.conf /etc/nginx/nginx.conf

# Expose le port
EXPOSE 8083