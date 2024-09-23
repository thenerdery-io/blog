#!/bin/sh
curl -sSL https://dot.net/v1/dotnet-install.sh > dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh -c 8.0 -InstallDir ./dotnet
./dotnet/dotnet --version
./dotnet/dotnet build .
cd MyApp
npm install -D tailwindcss
npm run build
dotnet run --AppTasks=prerender --environment Production --BaseUrl "https://thenerdery.io"
