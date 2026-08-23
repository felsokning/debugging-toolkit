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

            $vsDevCmdPath = "C:$($directorySeparator)Program Files$($directorySeparator)Microsoft Visual Studio$($directorySeparator)18$($directorySeparator)$($flavour)$($directorySeparator)Common7$($directorySeparator)Tools$($directorySeparator)VsDevCmd.bat"
            $projectPath = "$($PWD)$($directorySeparator)src$($directorySeparator)cpp$($directorySeparator)UnmanagedDebugging.vcxproj"

            if ($x64) {
                $arch = "x64"
                $AssemblyPath = "$($PWD)$($directorySeparator)src$($directorySeparator)cpp$($directorySeparator)x64$($directorySeparator)release$($directorySeparator)UnmanagedDebugging.dll"
            }
            elseif ($x86) {
                $arch = "Win32"
                $AssemblyPath = "$($PWD)$($directorySeparator)src$($directorySeparator)cpp$($directorySeparator)Win32$($directorySeparator)release$($directorySeparator)UnmanagedDebugging.dll"
            }
            else {
                Write-Error -Message "Currently unsupported architecture. Did you plan for this?"
                break
            }

            # Run VsDevCmd.bat and msbuild in the same CMD session so environment variables persist
            $buildCommand = "& VsDevCmd.bat && cd /d & msbuild & exit"
            Write-Host -ForegroundColor Yellow "Building project (this may take a moment)..."
            cmd.exe /c "`"$vsDevCmdPath`" && msbuild `"$projectPath`" /p:Configuration=Release /p:Platform=$arch"

            if (Test-Path -Path $AssemblyPath -PathType Leaf) {
                Write-Host -ForegroundColor Green "Build completed successfully: $AssemblyPath"
                $AssemblyBuilt = $true
                break
            }
            else {
                Write-Warning -Message "Build may have failed — DLL not found at expected path. Trying next flavour..."
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
        $sb = @()
        foreach($po in $processOBj)
        {
            $sb += [Testing.Debug]::GetThreadWaitChainManaged($po.Id)
        }
        return $sb
    }
    else
    {
        return "No process can be found with the name given: $($Process)"
    }
}