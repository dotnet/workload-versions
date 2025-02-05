## Welcome to the .NET SDK Workload Versions repo

This repository contains the version information for .NET SDK Workloads.

### Pre-requisites for local VS insertion build

1. Install the latest [Visual Studio](https://visualstudio.microsoft.com/downloads/) with the .NET Desktop workload
  - Make sure to restart your PC after the installation is complete.
2. [Install Azure CLI](https://learn.microsoft.com/cli/azure/install-azure-cli-windows#install-or-update)
3. Run `az login` to authenticate
  - When it asks for a subscription to select, just press Enter. The default subscription selection does not affect DARC.
4. [Install DARC](https://github.com/dotnet/arcade/blob/main/Documentation/Darc.md#setting-up-your-darc-client)
5. [Add GitHub auth for DARC](https://github.com/dotnet/arcade/blob/main/Documentation/Darc.md#step-3-set-additional-pats-for-azure-devops-and-github-operations)
  - Use the [darc authenticate](https://github.com/dotnet/arcade/blob/main/Documentation/Darc.md#authenticate) command.
  - Generate the GitHub PAT [here](https://github.com/settings/tokens?type=beta). Create a fine-grained PAT instead of the classic PAT.
  - **Do not** create an AzDO PAT. Leave that entry blank in the darc-authenticate file for it to use local machine auth.
6. Request access to the [.NET Daily Internal Build Access](https://coreidentity.microsoft.com/manage/Entitlement/entitlement/netdailyinte-q2ql) entitlement
  - This allows the local AzDO machine auth to gather internal assets from AzDO.
  - **Send a message** to one of the primary owners on the entitlement page for approval after requesting access to the entitlement.
  - Should take about 20 mins for the entitlement process to complete (will appear on your [entitlements list](https://coreidentity.microsoft.com/manage/entitlement)) and another 30 mins the access to propagate to DARC. Basically, after approval, wait an hour until you actually attempt to build.