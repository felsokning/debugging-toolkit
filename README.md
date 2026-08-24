# debugging-toolkit

## Get-WaitChainAnalysis.ps1
A PowerShell script that builds a C++ solution and uses C# Source Definition to JIT and use DLL Import (of the C++ assembly) to leverage Win API calls to do wait chain analysis on a process.

### GitHub Action
The logic/behaviour is validated in the [GitHub Action `pull-request-build.yaml` Workflow](.github/workflows/pull-request-build.yaml) definition. 

It builds the C++ assembly against different Toolset and Win SDK targets and tests running the wait chain analysis against the `pwsh` process.