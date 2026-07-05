# Packs a Flutter Windows Release folder into a single-file portable exe with
# Enigma Virtual Box. The app itself is unchanged: account data still goes to
# the per-user data directory; EVB only virtualizes the DLLs + data/ folder.
#
#   pack_portable.ps1 -ReleaseDir <path\to\Release> -Output <path\to\out.exe>
#
# Requires enigmavbconsole.exe on PATH or at the default install location.
param(
    [Parameter(Mandatory = $true)][string]$ReleaseDir,
    [Parameter(Mandatory = $true)][string]$Output,
    [string]$ExeName = 'ava.exe',
    # Off: the process image stays the outer packed exe, so the app can copy
    # Platform.resolvedExecutable to reproduce itself (installer → uninstaller).
    [switch]$NoTempMap
)
$ErrorActionPreference = 'Stop'

$ReleaseDir = (Resolve-Path $ReleaseDir).Path
$OutputDir = Split-Path -Parent $Output
if (-not $OutputDir) { $OutputDir = '.' }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Path $OutputDir | Out-Null }
$Output = Join-Path (Resolve-Path $OutputDir).Path (Split-Path -Leaf $Output)

$console = Get-Command enigmavbconsole.exe -ErrorAction SilentlyContinue
if ($console) { $console = $console.Source }
else {
    $console = @(
        "${env:ProgramFiles(x86)}\Enigma Virtual Box\enigmavbconsole.exe",
        "$env:ProgramFiles\Enigma Virtual Box\enigmavbconsole.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $console) { throw 'enigmavbconsole.exe not found (install Enigma Virtual Box)' }

$exe = Join-Path $ReleaseDir $ExeName
if (-not (Test-Path $exe)) { throw "$ExeName not found in $ReleaseDir" }
$mapTemp = if ($NoTempMap) { 'False' } else { 'True' }

function Get-FileXml([string]$path) {
    $name = [System.Security.SecurityElement]::Escape((Split-Path -Leaf $path))
    $full = [System.Security.SecurityElement]::Escape($path)
    return @"
<File>
  <Type>2</Type>
  <Name>$name</Name>
  <File>$full</File>
  <ActiveX>False</ActiveX>
  <ActiveXInstall>False</ActiveXInstall>
  <Action>0</Action>
  <OverwriteDateTime>False</OverwriteDateTime>
  <OverwriteAttributes>0</OverwriteAttributes>
  <PassCommandLine>False</PassCommandLine>
</File>
"@
}

function Get-DirXml([string]$dir) {
    $sb = ''
    foreach ($d in Get-ChildItem -Directory $dir | Sort-Object Name) {
        $name = [System.Security.SecurityElement]::Escape($d.Name)
        $sb += "<File><Type>3</Type><Name>$name</Name><Action>0</Action><OverwriteDateTime>False</OverwriteDateTime><OverwriteAttributes>0</OverwriteAttributes><Files>`n"
        $sb += Get-DirXml $d.FullName
        $sb += "</Files></File>`n"
    }
    foreach ($f in Get-ChildItem -File $dir | Sort-Object Name) {
        # The launcher exe itself is the EVB input, not a virtualized file.
        if ($f.FullName -ieq $exe) { continue }
        $sb += Get-FileXml $f.FullName
    }
    return $sb
}

$entries = Get-DirXml $ReleaseDir
$project = @"
<?xml version="1.0" encoding="windows-1252"?>
<>
  <InputFile>$exe</InputFile>
  <OutputFile>$Output</OutputFile>
  <Files>
    <Enabled>True</Enabled>
    <DeleteExtractedOnExit>False</DeleteExtractedOnExit>
    <CompressFiles>True</CompressFiles>
    <Files>
      <File>
        <Type>3</Type>
        <Name>%DEFAULT FOLDER%</Name>
        <Action>0</Action>
        <OverwriteDateTime>False</OverwriteDateTime>
        <OverwriteAttributes>0</OverwriteAttributes>
        <Files>
$entries
        </Files>
      </File>
    </Files>
  </Files>
  <Registries>
    <Enabled>False</Enabled>
    <Registries/>
  </Registries>
  <Packaging>
    <Enabled>False</Enabled>
  </Packaging>
  <Options>
    <ShareVirtualSystem>False</ShareVirtualSystem>
    <MapExecutableWithTemporaryFile>$mapTemp</MapExecutableWithTemporaryFile>
    <TemporaryFileMask/>
    <AllowRunningOfVirtualExeFiles>True</AllowRunningOfVirtualExeFiles>
    <ProcessesOfAnyPlatforms>False</ProcessesOfAnyPlatforms>
  </Options>
  <Storage>
    <Files>
      <Enabled>False</Enabled>
      <Folder>%DEFAULT FOLDER%\</Folder>
      <RandomFileNames>False</RandomFileNames>
      <EncryptContent>False</EncryptContent>
    </Files>
  </Storage>
</>
"@

$evb = Join-Path $env:TEMP 'ava_portable.evb'
# EVB expects a windows-1252 project file, not UTF-8/BOM.
[System.IO.File]::WriteAllText($evb, $project, [System.Text.Encoding]::GetEncoding(1252))

& $console $evb
if ($LASTEXITCODE -ne 0) { throw "enigmavbconsole failed with exit code $LASTEXITCODE" }
if (-not (Test-Path $Output)) { throw "expected output $Output was not produced" }
Write-Host "packed: $Output ($([math]::Round((Get-Item $Output).Length / 1MB, 1)) MB)"
