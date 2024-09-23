#!/bin/sh
curl -sSL https://dot.net/v1/dotnet-install.sh > dotnet-install.sh
chmod +x dotnet-install.sh
./dotnet-install.sh -c 8.0 -InstallDir ./dotnet
./dotnet/dotnet --version
./dotnet/dotnet build .
pwd
ls -al
npm install -D tailwindcss
pwd
ls -al
npm --prefix ./MyApp run build
/opt/buildhome/repo/dotnet/dotnet run --AppTasks=prerender --environment Production --BaseUrl "https://thenerdery.io" --project /opt/buildhome/repo/MyApp
