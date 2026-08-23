param(
    [ValidateNotNullOrWhitespace()]
    [Parameter(ParameterSetName = 'x64')]
    [Parameter(ParameterSetName = 'x86')]
    [string]$Process,
    [Parameter(ParameterSetName = 'x64')]
    [switch]$x64,
    [Parameter(ParameterSetName = 'x86')]
    [switch]$x86
)

Write-Host -ForegroundColor Green "Starting Wait Chain Analysis for $($Process) on $([System.Environment]::OSVersion.VersionString)"

# Future-proofing for Linux Support (long time aways but better to plan now)
$directorySeparator = $([System.IO.Path]::DirectorySeparatorChar)
$AssemblyPath = [string]::Empty
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
            if ($x64) {
                $buildCppJob = Start-Job -ScriptBlock { "C:$($using:directorySeparator)Program Files$($using:directorySeparator)Microsoft Visual Studio$($using:directorySeparator)18$($using:directorySeparator)$($using:flavour)$($using:directorySeparator)Common7$($using:directorySeparator)Tools$($using:directorySeparator)VsDevCmd.bat" && msbuild "$($using:PWD)$($using:directorySeparator)src$($using:directorySeparator)cpp$($using:directorySeparator)UnmanagedDebugging.vcxproj" $($using:directorySeparator)p:configuration=release $($using:directorySeparator)p:platform=x64 }
                # Wait for the build job to finish
                while($buildCppJob.State -ne "Completed" -and $buildCppJob.State -ne "Failed") {
                    Write-Host "Waiting 5 seconds for the build job to complete... State: $($buildCppJob.State)"
                    Start-Sleep -Seconds 5
                }

                if ($buildCppJob.State -eq "Failed") {
                    Write-Error -Message "Build job failed. Please check the build logs for details."
                    break;
                }

                $buildCppJob | Format-List
                $result = $(Receive-Job -Job $buildCppJob)
                Write-Host -ForegroundColor Green "Build job completed successfully. Output:"
                Write-Object -InputObject $result

                $AssemblyPath = "$($PWD)$($directorySeparator)src$($directorySeparator)cpp$($directorySeparator)x64$($directorySeparator)release$($directorySeparator)unmanagedebugging.dll"
                break;
            }
            elseif ($x86) {
                Write-Host -ForegroundColor Green "Found VsDevCmd.bat for $($flavour)"
                $buildCppJob = Start-Job -ScriptBlock { "C:$($using:directorySeparator)Program Files$($using:directorySeparator)Microsoft Visual Studio$($using:directorySeparator)18$($using:directorySeparator)$($using:flavour)$($using:directorySeparator)Common7$($using:directorySeparator)Tools$($using:directorySeparator)VsDevCmd.bat" && msbuild"$($using:PWD)$($using:directorySeparator)src$($using:directorySeparator)cpp$($using:directorySeparator)UnmanagedDebugging.vcxproj" $($using:directorySeparator)p:configuration=release $($using:directorySeparator)p:platform=x86 }
                # Wait for the build job to finish
                while($buildCppJob.State -ne "Completed" -and $buildCppJob.State -ne "Failed") {
                    Write-Host "Waiting 5 seconds for the build job to complete... State: $($buildCppJob.State)"
                    Start-Sleep -Seconds 5
                }

                if ($buildCppJob.State -eq "Failed") {
                    Write-Error -Message "Build job failed. Please check the build logs for details."
                    break;
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

$AssemblyPath

Test-Path -Path $AssemblyPath -PathType Leaf -ErrorAction Stop

$Source = @"
    namespace Testing
    {
        using System;
        using System.Runtime.InteropServices;

        public static class Debug
        {
            [DllImport(@"$($AssemblyPath)")]
            public static extern IntPtr WctEntry(int id);

            public static string GetThreadWaitChainManaged(int id)
            {
                IntPtr returnIntPtr = IntPtr.Zero;
                returnIntPtr = WctEntry(id);
                if(returnIntPtr != IntPtr.Zero)
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
    return [Testing.Debug]::GetThreadWaitChainManaged($targetInt)
}
else
{
    $processOBj = [System.Diagnostics.Process]::GetProcessesByName($Process)
    if($processOBj.Count -gt 0)
    {
        $processObj
        $sb = @()
        foreach($po in $processOBj)
        {
            $po
            $sb += [Testing.Debug]::GetThreadWaitChainManaged($po.Id)
        }
        return $sb
    }
    else
    {
        return "No process can be found with the name given: $($Process)"
    }
}