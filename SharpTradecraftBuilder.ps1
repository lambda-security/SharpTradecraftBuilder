Set-MpPreference -DisableRealtimeMonitoring $true -ErrorAction SilentlyContinue | Out-Null
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$global:ProgressPreference = 'SilentlyContinue'
$baseDir = Join-Path -Path ([Environment]::GetFolderPath("UserProfile")) -ChildPath "SharpTradecraftBuilder"
$randomSleep = { Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 3.5) }

function SharpTradecraftBuilder {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [switch]$SetupEnvironment,

        [Parameter(Mandatory = $false)]
        [switch]$BuildPipeline,

        [Parameter(Mandatory = $false)]
        [string]$RepoList
    )

    if ($SetupEnvironment) {
        Setup-Environment
    }

    if ($BuildPipeline) {
        Build-Pipeline -RepoList $RepoList
    }
}

function Setup-Environment {
    Start-Transcript -Path (Join-Path -Path $baseDir -ChildPath "SetupEnvironment_log.log") -Append
    Write-Host "[INFO] setting up build environment with git, confuserex , vs community + workloads, and .net deprecated versions"

    if (-not (Test-Path "C:\Program Files\Git\bin\git.exe" -PathType Leaf)) {
        Write-Host "[INFO] downloading git for Windows"
        $git_release = `
            ( `
                ( `
                    Invoke-WebRequest "https://api.github.com/repos/git-for-windows/git/releases" -UseBasicParsing `
                ).Content | ConvertFrom-Json `
            ).assets.browser_download_url | Select-String -Pattern ".*-64-bit.exe" | Select-Object -First 1
        Invoke-RestMethod -Uri $git_release.Line -OutFile (Join-Path -Path ([Environment]::GetFolderPath("UserProfile")) -ChildPath "git_setup.exe")

        Write-Host "[INFO] installing git for Windows"
        Start-Process -FilePath (Join-Path -Path ([Environment]::GetFolderPath("UserProfile")) -ChildPath "git_setup.exe") -ArgumentList "/VERYSILENT /NORESTART" -Wait -Verbose
        & $randomSleep
    } else {
        Write-Host "[INFO] git already installed, skipping"
    }

    if (-not (Test-Path (Join-Path -Path $baseDir -ChildPath "ConfuserEx-CLI\Confuser.CLI.exe") -PathType Leaf)) {
        Write-Host "[INFO] downloading latest confuserex cli release"
        $confuser_release = `
            ( `
                ( `
                    Invoke-WebRequest "https://api.github.com/repos/mkaring/ConfuserEx/releases" -UseBasicParsing `
                ).Content | ConvertFrom-Json `
            ).assets.browser_download_url | Select-String -Pattern ".*-CLI.zip" | Select-Object -First 1
        Invoke-RestMethod -Uri $confuser_release.Line -OutFile (Join-Path -Path ([Environment]::GetFolderPath("UserProfile")) -ChildPath "ConfuserEx-CLI.zip")
        Expand-Archive `
            -Path (Join-Path -Path ([Environment]::GetFolderPath("UserProfile")) -ChildPath "ConfuserEx-CLI.zip") `
            -DestinationPath (Join-Path -Path $baseDir -ChildPath "ConfuserEx-CLI") -Force
    } else {
        Write-Host "[INFO] confuserex already installed, skipping"
    }

    if (-not (Test-Path "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" -PathType Leaf)) {
        Write-Host "[INFO] downloading vs community installer"
        (New-Object System.Net.WebClient).DownloadFile("https://c2rsetup.officeapps.live.com/c2r/downloadVS.aspx?sku=community&channel=Release&version=VS2022&passive=true&includeRecommended=true", (Join-Path -Path C:\Windows\Temp -ChildPath "VisualStudioSetup.exe"))

        Write-Host "[INFO] starting vs community bootstrapper"
        Start-Process -FilePath (Join-Path -Path C:\Windows\Temp -ChildPath "VisualStudioSetup.exe") -Wait -Verbose
        & $randomSleep

        Write-Host "[INFO] installing vs community workloads"

        Start-Process -FilePath "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" -ArgumentList "install --productId Microsoft.VisualStudio.Product.Community --channelUri https://aka.ms/vs/17/release/channel --add Microsoft.VisualStudio.Workload.ManagedDesktop --add Microsoft.Net.Component.4.8.TargetingPack --add Microsoft.Net.Component.4.7.TargetingPack --add Microsoft.Net.Component.4.6.2.TargetingPack --includeRecommended --locale en_US --passive --norestart" -Wait -Verbose
        & $randomSleep
    } else {
        Write-Host "[INFO] vs community already installed, skipping"
    }

    Write-Host "[INFO] downloading .net framework v3.5 from nuget"
    (New-Object System.Net.WebClient).DownloadFile("https://www.nuget.org/api/v2/package/Microsoft.NETFramework.ReferenceAssemblies.net35/1.0.3", (Join-Path -Path C:\Windows\Temp -ChildPath "Microsoft.NETFramework.ReferenceAssemblies.net35_1.0.3.zip"))

    Write-Host "[INFO] extracting .net framework v3.5 package"
    Expand-Archive -Path C:\Windows\Temp\Microsoft.NETFramework.ReferenceAssemblies.net35_1.0.3.zip -DestinationPath C:\Windows\Temp\_extract -Force | Out-Null

    Write-Host "[INFO] copying C:\Windows\Temp\_extract\build\.NETFramework\v3.5 to C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v3.5"
    Copy-Item -Path (Join-Path -Path C:\Windows\Temp\_extract -ChildPath build\.NETFramework\v3.5\*) -Destination "C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v3.5" -Recurse -Force

    Remove-Item -Path C:\Windows\Temp\_extract -Recurse -Force

    Write-Host "[INFO] downloading .net framework v4.0 from nuget"
    (New-Object System.Net.WebClient).DownloadFile("https://www.nuget.org/api/v2/package/Microsoft.NETFramework.ReferenceAssemblies.net40/1.0.3", (Join-Path -Path C:\Windows\Temp -ChildPath "Microsoft.NETFramework.ReferenceAssemblies.net40_1.0.3.zip"))

    Write-Host "[INFO] extracting .net framework v4.0 package"
    Expand-Archive -Path C:\Windows\Temp\Microsoft.NETFramework.ReferenceAssemblies.net40_1.0.3.zip -DestinationPath C:\Windows\Temp\_extract -Force | Out-Null

    Write-Host "[INFO] copying C:\Windows\Temp\_extract\build\.NETFramework\v4.0 to C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.0"
    Copy-Item -Path (Join-Path -Path C:\Windows\Temp\_extract -ChildPath build\.NETFramework\v4.0\*) -Destination "C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.0" -Recurse -Force

    Remove-Item -Path C:\Windows\Temp\_extract -Recurse -Force

    Write-Host "[INFO] downloading .net framework v4.5 from nuget"
    (New-Object System.Net.WebClient).DownloadFile("https://www.nuget.org/api/v2/package/Microsoft.NETFramework.ReferenceAssemblies.net45/1.0.3", (Join-Path -Path C:\Windows\Temp -ChildPath "Microsoft.NETFramework.ReferenceAssemblies.net45_1.0.3.zip"))

    Write-Host "[INFO] extracting .net framework v4.5 package"
    Expand-Archive -Path C:\Windows\Temp\Microsoft.NETFramework.ReferenceAssemblies.net45_1.0.3.zip -DestinationPath C:\Windows\Temp\_extract -Force | Out-Null

    Write-Host "[INFO] copying C:\Windows\Temp\_extract\build\.NETFramework\v4.5 to C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.5"
    Copy-Item -Path (Join-Path -Path C:\Windows\Temp\_extract -ChildPath build\.NETFramework\v4.5\*) -Destination "C:\Program Files (x86)\Reference Assemblies\Microsoft\Framework\.NETFramework\v4.5" -Recurse -Force

    Remove-Item -Path C:\Windows\Temp\_extract -Recurse -Force

    Remove-Item -Path (Join-Path -Path ([Environment]::GetFolderPath("UserProfile")) -ChildPath "ConfuserEx-CLI.zip") -Force
    Remove-Item -Path (Join-Path -Path ([Environment]::GetFolderPath("UserProfile")) -ChildPath "git_setup.exe") -Force
    Remove-Item -Path C:\Windows\Temp\Microsoft.NETFramework.ReferenceAssemblies.net35_1.0.3.zip -Force
    Remove-Item -Path C:\Windows\Temp\Microsoft.NETFramework.ReferenceAssemblies.net40_1.0.3.zip -Force
    Remove-Item -Path C:\Windows\Temp\Microsoft.NETFramework.ReferenceAssemblies.net45_1.0.3.zip -Force

    Stop-Transcript
}

function Build-Pipeline {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$RepoList
    )

    $reposDir              = Join-Path -Path $baseDir   -ChildPath "repos"
    $buildsDir             = Join-Path -Path $baseDir   -ChildPath "builds"
    $builderPath           = Join-Path -Path $baseDir   -ChildPath "builder.ps1"
    $sanityExecLog         = Join-Path -Path $buildsDir -ChildPath "sanity_exec_log.log"
    $sanityConfusedExecLog = Join-Path -Path $buildsDir -ChildPath "confused_sanity_exec_log.log"

    New-Item -Path $baseDir -ItemType Directory -Force | Out-Null
    New-Item -Path $reposDir -ItemType Directory -Force | Out-Null

    Start-Transcript -Path (Join-Path -Path $baseDir -ChildPath "SharpTradecraftBuilder_log.log") -Append

    if (-not (Test-Path "C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat" -PathType Leaf)) {
        Write-Host "[ERR] `"C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat`" not found"
        Write-Host "[ERR] Visual Studio Community 2022 might not be present"
        return
    }

    if ($RepoList) {
        if (Test-Path $RepoList -PathType Leaf) {
            if ((Get-Item $RepoList).length -gt 0) {
                Write-Host "[INFO] using supplied repo list"
                $repos = Get-Content $RepoList
            } else {
                Write-Host "[ERR] $RepoList is empty"
            }
        } else {
            Write-Host "[ERR] $RepoList does not exist or is not a file"
        }
    } else {
        Write-Host "[INFO] using default repo list"
        $repos = @(
            "https://github.com/0xthirteen/SharpMove",
            "https://github.com/0xthirteen/SharpRDP",
            "https://github.com/0xthirteen/SharpStay",
            "https://github.com/airzero24/WMIReg",
            "https://github.com/AlmondOffSec/PassTheCert",
            "https://github.com/anthemtotheego/SharpExec",
            "https://github.com/antonioCoco/RunasCs",
            "https://github.com/b4rtik/SharpKatz",
            "https://github.com/b4rtik/SharpMiniDump",
            "https://github.com/bats3c/ADCSPwn",
            "https://github.com/BloodHoundAD/SharpHound",
            "https://github.com/CCob/SharpBlock",
            "https://github.com/CCob/SweetPotato",
            "https://github.com/chrismaddalena/SharpCloud",
            "https://github.com/cube0x0/KrbRelay",
            "https://github.com/cube0x0/SharpMapExec",
            "https://github.com/Dec0ne/KrbRelayUp",
            "https://github.com/Dec0ne/ShadowSpray",
            "https://github.com/djhohnstein/SharpChromium",
            "https://github.com/djhohnstein/SharpSearch",
            "https://github.com/djhohnstein/SharpShares",
            "https://github.com/dsnezhkov/TruffleSnout",
            "https://github.com/eladshamir/Whisker",
            "https://github.com/FatRodzianko/SharpBypassUAC",
            "https://github.com/fireeye/ADFSDump",
            "https://github.com/fireeye/SharPersist",
            "https://github.com/Flangvik/BetterSafetyKatz",
            "https://github.com/Flangvik/DeployPrinterNightmare",
            "https://github.com/Flangvik/SharpAppLocker",
            "https://github.com/FortyNorthSecurity/EDD",
            "https://github.com/FortyNorthSecurity/SqlClient",
            "https://github.com/FSecureLABS/SharpGPOAbuse",
            "https://github.com/fullmetalcache/SharpFiles",
            "https://github.com/FuzzySecurity/StandIn",
            "https://github.com/G0ldenGunSec/SharpSecDump",
            "https://github.com/GhostPack/Certify",
            "https://github.com/GhostPack/ForgeCert",
            "https://github.com/GhostPack/LockLess",
            "https://github.com/GhostPack/Rubeus",
            "https://github.com/GhostPack/SafetyKatz",
            "https://github.com/GhostPack/Seatbelt",
            "https://github.com/GhostPack/SharpDPAPI",
            "https://github.com/GhostPack/SharpDump",
            "https://github.com/GhostPack/SharpUp",
            "https://github.com/GhostPack/SharpWMI",
            "https://github.com/Group3r/Group3r",
            "https://github.com/HunnicCyber/SharpSniper",
            "https://github.com/HuskyHacks/SharpTokenFinder",
            "https://github.com/infosecn1nja/SharpDoor",
            "https://github.com/JamesCooteUK/SharpSphere",
            "https://github.com/jfmaes/SharpHandler",
            "https://github.com/jnqpblc/SharpDir",
            "https://github.com/jnqpblc/SharpReg",
            "https://github.com/jnqpblc/SharpSpray",
            "https://github.com/jnqpblc/SharpSvc",
            "https://github.com/jnqpblc/SharpTask",
            "https://github.com/juliourena/SharpNoPSExec",
            "https://github.com/l0ss/Grouper2",
            "https://github.com/lefayjey/SharpSQLPwn",
            "https://github.com/MartinIngesen/TokenStomp",
            "https://github.com/matterpreter/Shhmon",
            "https://github.com/Mayyhem/SharpSCCM",
            "https://github.com/mgeeky/SharpWebServer",
            "https://github.com/mitchmoser/AtYourService",
            "https://github.com/mvelazc0/PurpleSharp",
            "https://github.com/nccgroup/nccfsas",
            "https://github.com/pkb1s/SharpAllowedToAct",
            "https://github.com/PwnDexter/SharpEDRChecker",
            "https://github.com/r3nhat/SharpWifiGrabber",
            "https://github.com/RedLectroid/SearchOutlook",
            "https://github.com/rvrsh3ll/SharpCOM",
            "https://github.com/rvrsh3ll/SharpPrinter",
            "https://github.com/s0lst1c3/SharpFinder",
            "https://github.com/shantanu561993/SharpChisel",
            "https://github.com/slyd0g/SharpCrashEventLog",
            "https://github.com/SnaffCon/Snaffler",
            "https://github.com/swisskyrepo/SharpLAPS",
            "https://github.com/tomcarver16/ADSearch",
            "https://github.com/ustayready/SharpHose",
            "https://github.com/V1V1/SharpScribbles",
            "https://github.com/vivami/SauronEye"
        )
    }

    $repos | % {
        $repo = $_
        try {
            $response = Invoke-WebRequest -Uri $repo -UseBasicParsing
            if ($response.StatusCode -eq 200) {
                Write-Host "[INFO] cloning $repo"
                Start-Process -FilePath git -ArgumentList "-C $reposDir clone $repo -q" -Wait -Verbose
                & $randomSleep
            } else {
                Write-Host "[ERR] $repo does not exist or is private (HTTP response != 200)"
            }
        } catch {
            if ($_.Exception.Response -ne $null) {
                $statusCode = $_.Exception.Response.StatusCode.value__
                Write-Host "[ERR] $repo does not exist or is private (HTTP response == $statusCode)"
            } else {
                Write-Host "[ERR] error when accessing $repo (HTTP response == null)"
            }
        }
    }

    $builderScript = @'
$randomSleep = { Start-Sleep -Seconds (Get-Random -Minimum 2 -Maximum 3.5) }
$baseDir     = Join-Path -Path ([Environment]::GetFolderPath("UserProfile")) -ChildPath "SharpTradecraftBuilder"
$buildsDir   = Join-Path -Path $baseDir -ChildPath "builds"
$slnFilePath = Join-Path -Path $baseDir -ChildPath SharpTradecraftBuilder.sln
$csprojFiles = Get-ChildItem -Path $reposDir -Filter "*.csproj" -Recurse -File -Exclude '*\test\*', '*\tests\*'

dotnet new sln -o $baseDir --force
$csprojFiles | % {
    dotnet sln $baseDir add $_.FullName
    & $randomSleep
}

$slnContent = Get-Content $slnFilePath
$preSolution= '^\s*Release\|Any CPU\s*=\s*Release\|Any CPU\s*$'
$activeCfgPattern = '^.+\.Release\|Any CPU\.ActiveCfg = Release\|Any CPU$'
$buildPattern = '^.+\.Release\|Any CPU\.Build\.0 = Release\|Any CPU$'
$indexOfLine = ($slnContent | Select-String -Pattern $preSolution).LineNumber - 1

if ($indexOfLine -ge 0) {
    $slnContent[$indexOfLine] += "`r`nRelease|x64 = Release|x64"
    $slnContent[$indexOfLine] += "`r`nRelease|x86 = Release|x86"
}

for ($i = 0; $i -lt $slnContent.Length; $i++) {
    $line = $slnContent[$i].Trim()
    if ($line -match $activeCfgPattern) {
        $slnContent[$i] += "`r`n" + $line.Replace(".Release|Any CPU.ActiveCfg = Release|Any CPU", ".Release|x64.ActiveCfg = Release|x64")
        $slnContent[$i] += "`r`n" + $line.Replace(".Release|Any CPU.ActiveCfg = Release|Any CPU", ".Release|x86.ActiveCfg = Release|x86")
    }

    if ($line -match $buildPattern) {
        $slnContent[$i] += "`r`n" + $line.Replace(".Release|Any CPU.Build.0 = Release|Any CPU", ".Release|x64.Build.0 = Release|x64")
        $slnContent[$i] += "`r`n" + $line.Replace(".Release|Any CPU.Build.0 = Release|Any CPU", ".Release|x86.Build.0 = Release|x86")
    }
}

$slnContent | Set-Content $slnFilePath -Force

$dotnetVersions = @("v4.8", "v4.7", "v4.6.2", "v4.5", "v4.0", "v3.5")
$architectures = @("x64", "x86", "Any CPU")

foreach ($dotnetVersion in $dotnetVersions) {
    foreach ($architecture in $architectures) {
        $outputVersionDir = Join-Path -Path "$baseDir" -ChildPath "builds\NETFramework`_$dotnetVersion`_$architecture"
        $p = Start-Process -FilePath MSBuild.exe -ArgumentList "/t:build /p:Configuration=Release /p:TargetFrameworkVersion=$dotnetVersion /p:OutputPath=$outputVersionDir /p:Platform=$architecture $baseDir" -PassThru
        $p.WaitForExit()
        & $randomSleep
    }
}
Get-ChildItem -Path "$buildsDir" -Recurse -Include *.config, *.pdb | Remove-Item -Force
'@

    $builderScript | Out-File $builderPath

    Write-Host "[INFO] building custom sln with multiple projects"
    Write-Host "[INFO] targeting .net framework v4.8, v4.7, v4.6.2, v4.5, v4.0, v3.5 on x64, x86, Any CPU"
    Start-Process -FilePath ([Environment]::GetEnvironmentVariable("ComSpec")) -ArgumentList "/c `"C:\Program Files\Microsoft Visual Studio\2022\Community\Common7\Tools\VsDevCmd.bat`" & powershell -file $builderPath" -Wait -Verbose
    & $randomSleep

    Write-Host "[INFO] executing sanity check on builds to ensure they run"
    $exeFiles = Get-ChildItem -Path $buildsDir -Filter "*.exe" -Recurse -File | ? { $_.FullName -inotmatch "confused" }
    $exeFiles | % {
        $p = Start-Process -FilePath $_.FullName -PassThru
        $timeout = 5
        $startTime = Get-Date

        while ($true) {
            Start-Sleep -Milliseconds 500
            $p.Refresh()
            if ($p.HasExited) {
                if ($p.ExitCode -in 0, 1, -1) {
                    Write-Output "[OK] $($_.FullName)" | Tee-Object -Append -FilePath $sanityExecLog
                } else {
                    Write-Output "[NOK] $($_.FullName) ($($p.ExitCode))" | Tee-Object -Append -FilePath $sanityExecLog
                }
                break
            }

            if ((((Get-Date) - $startTime).TotalSeconds -ge $timeout)) {
                Write-Output "[TIMEOUT] $($_.FullName)" | Tee-Object -Append -FilePath $sanityExecLog
                $p.Kill()
                break
            }
        }
    }

    Write-Host "[INFO] starting confuserex pipeline"
    foreach ($exeFile in $exeFiles) {
        $parentDir = (Split-Path -Parent $exeFile.FullName)
        $confusedDir = Join-Path -Path $parentDir -ChildPath "Confused"
        @"
<project outputDir="$confusedDir" baseDir="$parentDir" xmlns="http://confuser.codeplex.com">
  <module path="$($exeFile.FullName)">
    <rule pattern="true" inherit="false">
      <protection id="anti debug" />
      <!-- <protection id="anti dump" />        -->
      <!-- <protection id="anti ildasm" />      -->
      <!-- <protection id="anti tamper" />      -->
      <protection id="constants" />
      <!-- <protection id="ctrl flow" />        -->
      <!-- <protection id="harden" />           -->
      <!-- <protection id="invalid metadata" /> -->
      <!-- <protection id="ref proxy" />        -->
      <protection id="resources" />
      <!-- <protection id="typescramble" />     -->
      <protection id="rename" />
    </rule>
  </module>
</project>
"@ | Out-File (Join-Path -Path $baseDir -ChildPath temp_confuse.crproj)

    if (-not (Test-Path (Join-Path -Path $baseDir -ChildPath "ConfuserEx-CLI\Confuser.CLI.exe") -PathType Leaf)) {
        Write-Host "[ERR] confuserex not found, skipping obfuscation"
        Write-Host "[ERR] reinstall the setup environment"
        return
    }
    Write-Host "[INFO] confusing $($exeFile.FullName) to $confusedDir"

    Start-Process -FilePath (Join-Path -Path $baseDir -ChildPath "ConfuserEx-CLI\Confuser.CLI.exe") -ArgumentList "$(Join-Path -Path $baseDir -ChildPath temp_confuse.crproj) -n" -Wait -Verbose
    & $randomSleep
}
    Remove-Item (Join-Path -Path $baseDir -ChildPath temp_confuse.crproj) -Force


    Write-Host "[INFO] executing sanity check on confused builds to ensure they run"
    Get-ChildItem -Path $baseDir -Directory -Recurse | Where-Object { $_.Name -eq "Confused" } | ForEach-Object { Get-ChildItem -Path $_.FullName -Filter "*.exe" -Recurse -File } | % {
        $p = Start-Process -FilePath $_.FullName -PassThru
        $timeout = 5
        $startTime = Get-Date

        while ($true) {
            Start-Sleep -Milliseconds 500
            $p.Refresh()
            if ($p.HasExited) {
                if ($p.ExitCode -in 0, 1, -1) {
                    Write-Output "[OK] $($_.FullName)" | Tee-Object -Append -FilePath $sanityExecLog
                } else {
                    Write-Output "[NOK] $($_.FullName) ($($p.ExitCode))" | Tee-Object -Append -FilePath $sanityExecLog
                }
                break
            }

            if ((((Get-Date) - $startTime).TotalSeconds -ge $timeout)) {
                Write-Output "[TIMEOUT] $($_.FullName)" | Tee-Object -Append -FilePath $sanityExecLog
                $p.Kill()
                break
            }
        }
    }
    Stop-Transcript
}
