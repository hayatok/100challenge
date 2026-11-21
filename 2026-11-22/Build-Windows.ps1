param([string]$Editor = "$env:ProgramFiles/Unity/Hub/Editor/6000.3.28f1/Editor/Unity.exe")
$ErrorActionPreference = "Stop"
$gameProject = (Resolve-Path (Join-Path $PSScriptRoot "Game")).Path
$buildFolder = Join-Path $PSScriptRoot "Builds"
New-Item -ItemType Directory -Force -Path $buildFolder | Out-Null
$logFile = Join-Path $buildFolder "editor.log"
$build = Start-Process -FilePath $Editor -ArgumentList @("-batchmode", "-quit", "-projectPath", ('"' + $gameProject + '"'), "-executeMethod", "KinseiBuild.Windows", "-logFile", ('"' + $logFile + '"')) -WindowStyle Hidden -Wait -PassThru
if ($build.ExitCode -ne 0) {
    Get-Content -LiteralPath $logFile -Tail 55
    throw "Unity build failed with exit code $($build.ExitCode)."
}
Get-Item -LiteralPath (Join-Path $buildFolder "Windows/Kinsei.exe") | Select-Object FullName, LastWriteTime

