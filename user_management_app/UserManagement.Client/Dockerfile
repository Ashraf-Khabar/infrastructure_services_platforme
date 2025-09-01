FROM mcr.microsoft.com/dotnet/sdk:8.0 AS build
WORKDIR /src
COPY ["UserManagement.Client.csproj", "."]
RUN dotnet restore "UserManagement.Client.csproj"
COPY . .
RUN dotnet build "UserManagement.Client.csproj" -c Release -o /app/build

FROM build AS publish
RUN dotnet publish "UserManagement.Client.csproj" -c Release -o /app/publish

FROM nginx:alpine AS final
WORKDIR /usr/share/nginx/html

# Supprimer tous les fichiers existants
RUN rm -rf /usr/share/nginx/html/*

COPY --from=publish /app/publish/wwwroot .
COPY nginx.conf /etc/nginx/nginx.conf

# S'assurer que les permissions sont correctes
RUN chmod -R 755 /usr/share/nginx/html