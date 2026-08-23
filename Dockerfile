FROM mcr.microsoft.com/windows/servercore:ltsc2019

RUN winget install --id Microsoft.PowerShell --source winget --installer-type wix \
    && winget configure -f 'https://raw.githubusercontent.com/microsoft/Windows-driver-samples/main/_wdk_utils/winget/configs/wdk-vsenterprise.dsc.yaml'