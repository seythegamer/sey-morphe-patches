# Compiles the Java extensions of both apps into raw DEX files.
#
# KICK (Android TV):
#   extension\dex\kick-seyttings\classes.dex    - base SEYTTINGS module
#   extension\dex\kick-emotes\classes.dex       - EMOTES feature module
#   extension\dex\kick-chatsize\classes.dex     - CHAT SIZE feature module
#   extension\dex\kick-chattext\classes.dex     - CHAT TEXT SIZE feature module
#   extension\dex\kick-chatexpand\classes.dex   - EXPAND CHAT feature module
#
# Twitch (Android TV):
#   extension\dex\twitch-seyttings\classes.dex  - base SEYTTINGS module
#   extension\dex\twitch-emotes\classes.dex     - EMOTES feature module
#   extension\dex\twitch-expandchat\classes.dex - EXPAND CHAT feature module
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '_common.ps1')
Set-Location $script:RepoRoot

$sdkRoot = Get-AndroidSdkRoot
$androidJar = Get-AndroidJar $sdkRoot
$buildTools = Get-BuildToolsDir $sdkRoot
$d8 = Join-Path $buildTools 'd8.bat'
$kotlinStdlib = Get-KotlinStdlib

if (-not (Test-Path $d8)) {
    throw "d8.bat not found in $buildTools."
}

$srcRoot = Join-Path $script:RepoRoot 'extension\src'
$classesRoot = Join-Path $script:RepoRoot 'extension\classes'
$dexRoot = Join-Path $script:RepoRoot 'extension\dex'

Remove-Item $classesRoot, $dexRoot -Recurse -Force -ErrorAction SilentlyContinue

function Get-Sources([string]$directory, [string]$label) {
    if (-not (Test-Path $directory)) {
        throw "$label source directory not found: $directory"
    }
    $files = Get-ChildItem $directory -Filter '*.java' | ForEach-Object { $_.FullName }
    if (-not $files) {
        throw "No $label Java sources found in $directory."
    }
    return $files
}

function New-Dex([string]$outDir, [string[]]$classFiles, [string]$classpath, [string]$label) {
    $arguments = @('--min-api', '26', '--lib', $androidJar, '--output', $outDir)
    if ($classpath) {
        $arguments += @('--classpath', $classpath)
    }
    $arguments += $classFiles

    & $d8 @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "d8 failed on the $label extension with exit code $LASTEXITCODE."
    }

    $dex = Join-Path $outDir 'classes.dex'
    if (-not (Test-Path $dex)) {
        throw "d8 did not produce $dex."
    }
    Write-Host "$label extension DEX: $dex ($((Get-Item $dex).Length) bytes)"
    return $dex
}

function Build-Module {
    param(
        [string]$Label,
        [string]$SourceDir,
        [string]$ClassesDir,
        [string]$DexDir,
        [string]$BaseClasses
    )

    New-Item $ClassesDir, $DexDir -ItemType Directory -Force | Out-Null
    $sources = Get-Sources $SourceDir $Label

    Write-Host "Compiling $Label extension ($($sources.Count) files)..."
    $classpath = "$androidJar;$kotlinStdlib"
    if ($BaseClasses) {
        $classpath += ";$BaseClasses"
    }
    & javac --release 8 -encoding UTF-8 -classpath $classpath -d $ClassesDir $sources
    if ($LASTEXITCODE -ne 0) {
        throw "javac failed on the $Label extension with exit code $LASTEXITCODE."
    }

    $classFiles = Get-ChildItem $ClassesDir -Recurse -Filter '*.class' | ForEach-Object { $_.FullName }
    $null = New-Dex -outDir $DexDir -classFiles $classFiles -classpath $BaseClasses -label $Label
}

$kickBaseSrc = Join-Path $srcRoot 'app\morphe\extension\kicktv\base'
$kickEmoteSrc = Join-Path $srcRoot 'app\morphe\extension\kicktv\emotes'
$kickChatSrc = Join-Path $srcRoot 'app\morphe\extension\kicktv\chat'
$kickChatTextSrc = Join-Path $srcRoot 'app\morphe\extension\kicktv\chattext'
$kickChatExpandSrc = Join-Path $srcRoot 'app\morphe\extension\kicktv\chatexpand'

$twitchBaseSrc = Join-Path $srcRoot 'app\morphe\extension\twitch\base'
$twitchEmoteSrc = Join-Path $srcRoot 'app\morphe\extension\twitch\emotes'
$twitchExpandChatSrc = Join-Path $srcRoot 'app\morphe\extension\twitch\expandchat'

$kickBaseClasses = Join-Path $classesRoot 'kick-base'
$twitchBaseClasses = Join-Path $classesRoot 'twitch-base'

Build-Module -Label 'KICK base' -SourceDir $kickBaseSrc `
    -ClassesDir $kickBaseClasses -DexDir (Join-Path $dexRoot 'kick-seyttings')

Build-Module -Label 'Twitch base' -SourceDir $twitchBaseSrc `
    -ClassesDir $twitchBaseClasses -DexDir (Join-Path $dexRoot 'twitch-seyttings')

Build-Module -Label 'KICK emotes' -SourceDir $kickEmoteSrc `
    -ClassesDir (Join-Path $classesRoot 'kick-emotes') `
    -DexDir (Join-Path $dexRoot 'kick-emotes') -BaseClasses $kickBaseClasses

Build-Module -Label 'KICK chat size' -SourceDir $kickChatSrc `
    -ClassesDir (Join-Path $classesRoot 'kick-chatsize') `
    -DexDir (Join-Path $dexRoot 'kick-chatsize') -BaseClasses $kickBaseClasses

Build-Module -Label 'KICK chat text' -SourceDir $kickChatTextSrc `
    -ClassesDir (Join-Path $classesRoot 'kick-chattext') `
    -DexDir (Join-Path $dexRoot 'kick-chattext') -BaseClasses $kickBaseClasses

Build-Module -Label 'KICK expand chat' -SourceDir $kickChatExpandSrc `
    -ClassesDir (Join-Path $classesRoot 'kick-chatexpand') `
    -DexDir (Join-Path $dexRoot 'kick-chatexpand') -BaseClasses $kickBaseClasses

Build-Module -Label 'Twitch emotes' -SourceDir $twitchEmoteSrc `
    -ClassesDir (Join-Path $classesRoot 'twitch-emotes') `
    -DexDir (Join-Path $dexRoot 'twitch-emotes') -BaseClasses $twitchBaseClasses

Build-Module -Label 'Twitch expand chat' -SourceDir $twitchExpandChatSrc `
    -ClassesDir (Join-Path $classesRoot 'twitch-expandchat') `
    -DexDir (Join-Path $dexRoot 'twitch-expandchat') -BaseClasses $twitchBaseClasses
