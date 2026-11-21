param([string]$Project,[string]$OutDir=$PSScriptRoot,[string]$NightSource)
if (!$NightSource){$NightSource="$Project/Game/Assets/Kinsei/World/KinseiWorld.Nightscape.cs"}
$night=Get-Content -Raw $NightSource
$window=$night.Substring($night.IndexOf('    static void BuildDomesticWindow'),$night.IndexOf('    static void CreateEveningSurround')-$night.IndexOf('    static void BuildDomesticWindow'))
$geometry=$night.Substring($night.IndexOf('    sealed class NightGeometry'),$night.IndexOf('        public void Upload')-$night.IndexOf('    sealed class NightGeometry'))
$upload=@"
public void Upload(object p,Material m,KinseiNightAssets a){
writer.Write(m.name);writer.Write(positions.Count);
foreach(var v in positions){writer.Write(v.x);writer.Write(v.y);writer.Write(v.z);}
}}
}
"@
$stub=(Get-Content -Raw "$PSScriptRoot/stub.txt")
$modelPath="$PSScriptRoot/../../Assets/Kinsei/World/KinseiWorld.StreetEnds.cs"
if (!(Test-Path -LiteralPath $modelPath)){$modelPath="$Project/Game/Assets/Kinsei/World/KinseiWorld.StreetEnds.cs"}
$fixturePath=Join-Path (Split-Path $modelPath) 'KinseiWorld.StreetLighting.cs'
$fixtureSource=Get-Content -Raw $fixturePath
$fixtureStart=$fixtureSource.IndexOf('    static void MakeStreetFixtures(')
$fixtureEnd=$fixtureSource.IndexOf('    void BuildStreetFixtures(')
$stub+=$fixtureSource.Substring($fixtureStart,$fixtureEnd-$fixtureStart)
$model=(Get-Content -Raw $modelPath).Replace('using UnityEngine;','')
Add-Type -TypeDefinition ("using UnityEngine;`n"+$stub+$window+$geometry+$upload+$model)
[KinseiWorld]::Dump("$OutDir/geometry.bin")

