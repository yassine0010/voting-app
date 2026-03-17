FROM mcr.microsoft.com/dotnet/sdk:7.0-alpine AS build
WORKDIR /src

# Copy only project files first (for better build caching)
COPY *.csproj .
RUN dotnet restore

# Copy everything else and build
COPY . .
RUN dotnet publish -c Release -o /app/publish /p:UseAppHost=false


# ============================
# Stage 2: Runtime image
# ============================

FROM mcr.microsoft.com/dotnet/runtime:7.0-alpine as final
WORKDIR /app

# Create a non-root user/group
RUN addgroup -S app && adduser -S app -G app

# Copy published output
COPY --from=build /app/publish .

# Fix ownership so the non-root user can read the app
RUN chown -R app:app /app
USER app
  
# Run the app
ENTRYPOINT ["dotnet", "Worker.dll"]