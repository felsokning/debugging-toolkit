param(
    [ValidateNotNullOrWhitespace()]
    [string]
    [Parameter(ParameterSetName = 'x64')]
    [Parameter(ParameterSetName = 'x86')]
    $Process,
    [Parameter(ParameterSetName = 'x64')]
    [switch]
    x64,
    [Parameter(ParameterSetName = 'x86')]
    [switch]
    x86
)
# Future-proofing for Linux Support (long time aways but better to plan now)
$directorySeparator = $([System.IO.Path]::DirectorySeparatorChar)
if (-not ([System.OperatingSystem]::IsWindows())) {
    Write-Error -Message "Non-Windows Systems are currently unsupported. Planned for future - when time to invest in researching the API Calls presents itself."
    # TODO: Figure out the Linux equivalent and implement that here.
}
else {
    $flavours = "Enterprise", "Developer", "Community"
    # VS2026
    foreach ($flavour in $flavours){
        # VS2026
        if (Test-Path -Path "C:$($directorySeparator)Program Files$($directorySeparator)Microsoft Visual Studio$($directorySeparator)18$($directorySeparator)$($flavour)$($directorySeparator)Common7$($directorySeparator)Tools$($directorySeparator)VsDevCmd.bat") {
            Write-Host -ForegroundColor Green "Found VsDevCmd.bat for $($flavour)"
            if (x64) {
                $buildJob = $(Start-Job -ScriptBlock { "C:$($directorySeparator)Program Files$($directorySeparator)Microsoft Visual Studio$($directorySeparator)18$($directorySeparator)$($flavour)$($directorySeparator)Common7$($directorySeparator)Tools$($directorySeparator)VsDevCmd.bat"; msbuild "$($PWD)$($directorySeparator)src$($directorySeparator)cpp$($directorySeparator)UnmanagedDebugging.vcxproj" $($directorySeparator)p:configuration=release $($directorySeparator)p:platform=x64 })
                # Wait for the build job to finish
                while($($buildJob.State -ne "Completed") -or $($buildJob.State -ne "Failed")) {
                    Write-Host "Waiting 5 seconds for the build job to complete... State: $($buildJob.State)"
                    Start-Sleep -Seconds 5
                }

                $AssemblyPath = "$($PWD)$($directorySeparator)src$($directorySeparator)cpp$($directorySeparator)x64$($directorySeparator)release$($directorySeparator)unmanagedebugging.dll"
                break;
            }
            else if (x86) {
                Write-Host -ForegroundColor Green "Found VsDevCmd.bat for $($flavour)"
                $buildJob = $(Start-Job -ScriptBlock { "C:$($directorySeparator)Program Files$($directorySeparator)Microsoft Visual Studio$($directorySeparator)18$($directorySeparator)$($flavour)$($directorySeparator)Common7$($directorySeparator)Tools$($directorySeparator)VsDevCmd.bat"; msbuild "$($PWD)$($directorySeparator)src$($directorySeparator)cpp$($directorySeparator)UnmanagedDebugging.vcxproj" $($directorySeparator)p:configuration=release $($directorySeparator)p:platform=x86 })
                # Wait for the build job to finish
                while($($buildJob.State -ne "Completed") -or $($buildJob.State -ne "Failed")) {
                    Write-Host "Waiting 5 seconds for the build job to complete... State: $($buildJob.State)"
                    Start-Sleep -Seconds 5
                }

                $AssemblyPath = "$($PWD)$($directorySeparator)src$($directorySeparator)cpp$($directorySeparator)x86$($directorySeparator)release$($directorySeparator)unmanagedebugging.dll"
                break;
            }
            else {
                Write-Error -Message "Currently unsupported architecture. Did you plan for this?"
                break;
            }
        }
    }
}

$Source = @"
    namespace Testing
    {
        using System;
        using System.Runtime.InteropServices;

        public static class Debug
        {
            [DllImport($($AssemblyPath))]
            public static extern IntPtr ExternalEntry(int id);

            public static string GetThreadWaitChain(int id)
            {
                IntPtr returnIntPtr = IntPtr.Zero;
                returnIntPtr = ExternalEntry(id);
                if(returnIntPtr != null && returnIntPtr != IntPtr.Zero)
                {
                    return Marshal.PtrToStringUni(returnIntPtr);
                }
                else
                {
                    return "Something is not working";
                }
            }
        }
    }
"@

Add-Type -TypeDefinition $Source -Language CSharp -ReferencedAssemblies System.Runtime

# TODO: IIS Instances via the API for finding the Instance's Name to PID translation.

# First, we check that the parameter we were given is an int, if not, proceed as a string
[int]$targetInt = 0
if([int]::TryParse($Process, [ref]$targetInt))
{
    return [Testing.Debug]::GetThreadWaitChain($targetInt)
}
else
{
    $processOBj = [System.Diagnostics.Process]::GetProcessesByName($Process)
    if($processOBj.Count -gt 0)
    {
        $sb = @()
        foreach($po in $processOBj)
        {
            $sb += [Testing.Debug]::GetThreadWaitChain($po.Id)
        }
        return $sb
    }
    else
    {
        return "No process can be found with the name given :$($Process)"
    }
}