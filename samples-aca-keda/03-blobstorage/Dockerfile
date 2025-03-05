# Use the official .NET SDK image to build the app
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /app

# Copy the project file from the src folder and restore dependencies
COPY src/BlobStorageScaling.csproj ./
RUN dotnet restore BlobStorageScaling.csproj

# Copy the remaining files and build the app
COPY . ./
RUN dotnet publish src/BlobStorageScaling.csproj -c Release -o out

# Use the official .NET runtime image to run the app
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app/out .

# Run the app
ENTRYPOINT ["dotnet", "BlobStorageScaling.dll"]
