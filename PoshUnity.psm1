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

Set-Alias -Name opup -Value Open-UnityProject -Scope Global
Export-ModuleMember -Function Open-UnityProject -Alias opup

class Unity {
    [String]$ExecutablePath

    Unity([String]$ExecutablePath) {
        $this.ExecutablePath = $ExecutablePath
    }

    OpenProject([string]$ProjectPath) {
        Start-Process -FilePath $this.ExecutablePath -ArgumentList "-projectPath", $ProjectPath
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