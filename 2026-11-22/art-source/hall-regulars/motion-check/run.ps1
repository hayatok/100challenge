param([string]$Unity)
$ErrorActionPreference='Stop'
$project=(Resolve-Path (Join-Path $PSScriptRoot '../../../Game')).Path
if(-not $Unity){
    $version=((Get-Content (Join-Path $project 'ProjectSettings/ProjectVersion.txt') -First 1) -split ': ')[1]
    $Unity=Join-Path $env:ProgramFiles "Unity/Hub/Editor/$version/Editor/Unity.exe"
}
if(-not (Test-Path -LiteralPath $Unity)){throw "Unity Editor unavailable at $Unity"}
$run=Join-Path ([IO.Path]::GetTempPath()) ('kinsei-yield-'+[guid]::NewGuid().ToString('N'))
$copy=Join-Path $run 'Game'
foreach($dir in 'Assets','Packages','ProjectSettings'){
    $from=Join-Path $project $dir
    $to=Join-Path $copy $dir
    New-Item -ItemType Directory -Path $to -Force | Out-Null
    robocopy $from $to /E /NFL /NDL /NJH /NJS /NP | Out-Null
    if($LASTEXITCODE -ge 8){throw "Copy failed for $dir ($LASTEXITCODE)"}
}
# Play Mode creates the four actors explicitly. Disable the hall bootstrap only in this copy.
$session=Join-Path $copy 'Assets/Kinsei/Runtime/KinseiSession.cs'
$source=[IO.File]::ReadAllText($session)
$registration='[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.AfterSceneLoad)]'
if(-not $source.Contains($registration)){throw 'Could not locate the automatic hall bootstrap'}
[IO.File]::WriteAllText($session,$source.Replace($registration,'// The isolated actor test starts its own scene.'))
foreach($file in 'YieldProof.cs','TrouserSection.cs'){
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $copy 'Assets/Editor')
}
$log=Join-Path $run 'unity.log'
$process=Start-Process -FilePath $Unity -WindowStyle Hidden -Wait -PassThru -ArgumentList "-batchmode -nographics -projectPath `"$copy`" -executeMethod YieldProof.Run -logFile `"$log`""
if($process.ExitCode -ne 0 -or -not (Select-String -Quiet -LiteralPath $log -Pattern 'YIELD_MEASURE_PASS')){
    throw "Unity check failed. See $log"
}
python (Join-Path $PSScriptRoot 'section.py') (Join-Path $run 'final-surfaces.bin') (Join-Path $run 'knee-section.png')
if($LASTEXITCODE -ne 0){throw 'Could not draw the section'}
Write-Output $run
