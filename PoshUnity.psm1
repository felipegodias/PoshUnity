using namespace System.Linq
using namespace System.Diagnostics
using namespace System.Collections.Generic

$UnityHubExecutablePath = "C:\Program Files\Unity Hub\Unity Hub.exe"

function Open-UnityProject {
    param(
        [String]$Path
    )

    $UnityProject = [UnityProject]::new($Path)
    $UnityHub = [UnityHub]::new($UnityHubExecutablePath)
    $UnityVersion = $UnityProject.GetUnityVersion()
    $Unity = $UnityHub.GetUnityByVersion($UnityVersion)
    
    $Unity.OpenProject($UnityProject.ProjectPath)
}

function Invoke-UnityInBatchMode {
    param(
        [String]$Project,
        [String]$Method,
        [String[]]$Arguments
    )

    $LogFile = "$($Project)/Builds/PoshUnity/RunInBatchMode.log"

    $UnityProject = [UnityProject]::new($Project)
    $UnityHub = [UnityHub]::new($UnityHubExecutablePath)

    $UnityVersion = $UnityProject.GetUnityVersion()
    $Unity = $UnityHub.GetUnityByVersion($UnityVersion)
    
    $Unity.RunInBatchMode($UnityProject.ProjectPath, $Method, $Arguments, $LogFile)
}

Set-Alias -Name opup -Value Open-UnityProject -Scope Global
Export-ModuleMember -Function Open-UnityProject -Alias opup

Set-Alias -Name iubm -Value Invoke-UnityInBatchMode -Scope Global
Export-ModuleMember -Function Invoke-UnityInBatchMode -Alias iubm

class Unity {
    [String]$ExecutablePath 

    Unity([String]$ExecutablePath) {
        $this.ExecutablePath = $ExecutablePath
    }

    OpenProject([string]$ProjectPath) {
        Start-Process -FilePath $this.ExecutablePath -ArgumentList "-projectPath", $ProjectPath
    }

    RunInBatchMode([string]$ProjectPath, [string]$Method, [String[]]$Arguments, [string]$LogFile) {
        Clear-Content -Path $LogFile

        $ProcessInfo = [ProcessStartInfo]::new()
        $ProcessInfo.FileName = $this.ExecutablePath
        $ProcessInfo.UseShellExecute = $false

        $ProcessArguments = [List[String]]::new()
        $ProcessArguments.Add("-batchmode")
        $ProcessArguments.Add("-quit")
        $ProcessArguments.Add("-logFile")
        $ProcessArguments.Add($LogFile)
        $ProcessArguments.Add("-projectPath")
        $ProcessArguments.Add($ProjectPath)
        $ProcessArguments.Add("-executeMethod")
        $ProcessArguments.Add($Method)
        $ProcessArguments.AddRange($Arguments)

        $ProcessInfo.Arguments = $ProcessArguments.ToArray()

        $Process = [Process]::new()
        $Process.StartInfo = $ProcessInfo
        $Process.Start()

        $InvokeLogTailJob = Start-Job -ScriptBlock { Get-Content $Using:LogFile -Wait } -ArgumentList $LogFile

        while ($Process.HasExited -eq $false) {
            Receive-Job $InvokeLogTailJob | Out-Host
        }
        Start-Sleep -Seconds 1
        Receive-Job $InvokeLogTailJob | Out-Host
        Stop-Job $InvokeLogTailJob

        Remove-Job $InvokeLogTailJob
    }
}

class UnityHub {
    [String]$ExecutablePath

    UnityHub([String]$ExecutablePath) {
        $this.ExecutablePath = $ExecutablePath
    }

    [Unity]GetUnityByVersion($Version) {
        $ProcessInfo = [ProcessStartInfo]::new()
        $ProcessInfo.FileName = $this.ExecutablePath
        $ProcessInfo.RedirectStandardError = $true
        $ProcessInfo.RedirectStandardOutput = $true
        $ProcessInfo.UseShellExecute = $false
        $ProcessInfo.Arguments = "-- --headless editors --installed"

        $Process = [Process]::new()
        $Process.StartInfo = $ProcessInfo
        $Process.Start() | Out-Null
        $Process.WaitForExit()
    
        $ProcessStdOut = $Process.StandardOutput.ReadToEnd()
        $InstalledVersionsArray = $ProcessStdOut.Split("`n")

        $InstalledVersions = [Enumerable]::ToList($InstalledVersionsArray)
        $InstalledVersions.RemoveAt(0)
        $InstalledVersions.RemoveAt($InstalledVersions.Count - 1)
        
        foreach ($InstalledVersion in $InstalledVersions) {
            $InstalledVersionSplit = $InstalledVersion.Split(" , installed at ")
            $InstalledVersion = $InstalledVersionSplit[0]
            
            if ($InstalledVersion -eq $Version) {
                $InstalledPath = $InstalledVersionSplit[1]
                return [Unity]::new($InstalledPath)
            }
        }

        return $null
    }
}

class UnityProject {
    [string]$ProjectPath

    UnityProject([string]$ProjectPath) {
        $this.ProjectPath = $ProjectPath
    }

    [string]GetUnityVersion() {
        $ProjectVersionFile = "$($this.ProjectPath)/ProjectSettings/ProjectVersion.txt"

        $UnityVersion = Get-Content $ProjectVersionFile -First 1
        $UnityVersion = $UnityVersion.Split("m_EditorVersion: ")
        $UnityVersion = $UnityVersion[1]

        return $UnityVersion
    }
}