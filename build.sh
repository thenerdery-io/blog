#!/bin/sh
curl -sSL https://dot.net/v1/dotnet-install.sh > dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh -c 8.0 -InstallDir ./dotnet
./dotnet/dotnet --version
./dotnet/dotnet build .
npm install -D tailwindcss
npm --prefix ./MyApp run build
pwd
ls -al
./dotnet/dotnet run --AppTasks=prerender --environment Production --BaseUrl "https://thenerdery.io" --project ./MyApp
