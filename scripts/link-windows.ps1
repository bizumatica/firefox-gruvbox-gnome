<#
.SYNOPSIS
  Liga o perfil do Firefox a este repositório (Windows).

.DESCRIPTION
  <perfil>\chrome   ->  <repo>               (JUNCTION: não exige administrador)
  <perfil>\user.js  ->  <repo>\profile\user.js
                        (tenta link simbólico; se não puder, hardlink; senão, cópia)

  Opcional (-ImportPrivate): COPIA cert9.db, permissions.sqlite e prefs.js de uma pasta
  PRIVADA, fora do repositório, para o perfil. Esses arquivos nunca devem ir para o
  GitHub. São copiados (não ligados) porque o Firefox os reescreve.

.PARAMETER Profile
  Pasta do perfil (padrão: detecta pelo profiles.ini; veja about:support).
.PARAMETER PrivateDir
  Pasta privada com os 3 arquivos (padrão: %USERPROFILE%\.firefox-privado).
.PARAMETER ImportPrivate
  Copia cert9.db, permissions.sqlite e prefs.js para o perfil.
.PARAMETER SkipUserJs
  Não liga o user.js (útil se cada máquina usa um perfil de RAM diferente).
.PARAMETER Undo
  Remove os links e restaura os backups mais recentes.
.PARAMETER DryRun
  Só mostra o que faria.
.PARAMETER Force
  Ignora a checagem de "Firefox aberto" (não recomendado).

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\scripts\link-windows.ps1 -DryRun
  powershell -ExecutionPolicy Bypass -File .\scripts\link-windows.ps1 -ImportPrivate
  powershell -ExecutionPolicy Bypass -File .\scripts\link-windows.ps1 -Undo
#>
[CmdletBinding()]
param(
    [string]$Profile,
    [string]$PrivateDir = (Join-Path $env:USERPROFILE '.firefox-privado'),
    [switch]$ImportPrivate,
    [switch]$SkipUserJs,
    [switch]$Undo,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$TS = Get-Date -Format 'yyyyMMdd-HHmmss'
$PrivateFiles = @('cert9.db', 'permissions.sqlite', 'prefs.js')

function Log($m)  { Write-Host "• $m" }
function Warn($m) { Write-Host "! $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host "ERRO: $m" -ForegroundColor Red; exit 1 }

# Executa o bloco, ou só descreve quando -DryRun
function Do-It([scriptblock]$Block, [string]$Desc) {
    if ($DryRun) { Write-Host "[dry-run] $Desc" } else { & $Block }
}

# --- detecção do perfil padrão -----------------------------------------------
function Find-Profile {
    $base = Join-Path $env:APPDATA 'Mozilla\Firefox'
    $ini  = Join-Path $base 'profiles.ini'
    if (-not (Test-Path $ini)) { return $null }

    $data = [ordered]@{}; $sec = ''
    foreach ($l in (Get-Content $ini)) {
        if ($l -match '^\[(.+)\]$') { $sec = $Matches[1]; $data[$sec] = @{}; continue }
        if ($sec -and $l -match '^([^=]+)=(.*)$') { $data[$sec][$Matches[1]] = $Matches[2] }
    }
    # 1) perfil padrão da instalação: [Install...] Default=Profiles/xxxx
    foreach ($s in $data.Keys) {
        if ($s -like 'Install*' -and $data[$s]['Default']) {
            return (Join-Path $base ($data[$s]['Default'] -replace '/', '\'))
        }
    }
    # 2) perfil marcado Default=1
    foreach ($s in $data.Keys) {
        if ($s -like 'Profile*' -and $data[$s]['Default'] -eq '1') {
            $p = $data[$s]['Path']
            if ($data[$s]['IsRelative'] -eq '1') { return (Join-Path $base ($p -replace '/', '\')) }
            return $p
        }
    }
    return $null
}

function Latest-Backup([string]$Path) {
    $dir = Split-Path $Path -Parent; $name = Split-Path $Path -Leaf
    Get-ChildItem -Path $dir -Filter "$name.bak.*" -Force -ErrorAction SilentlyContinue |
        Sort-Object Name | Select-Object -Last 1
}

function Is-Link($item) { return ($null -ne $item) -and ($null -ne $item.LinkType) }

# --- operações ---------------------------------------------------------------
function Link-Dir([string]$Target, [string]$Link) {
    $item = Get-Item -LiteralPath $Link -Force -ErrorAction SilentlyContinue
    if ($item) {
        if ((Is-Link $item) -and (@($item.Target) -contains $Target)) {
            Log "ok: $Link já aponta para $Target"; return
        }
        if (Is-Link $item) {
            Do-It { cmd /c rmdir "$Link" | Out-Null } "remover o atalho antigo $Link"   # só o atalho
        } else {
            $bak = "$Link.bak.$TS"
            Do-It { Move-Item -LiteralPath $Link -Destination $bak } "mover $Link -> $bak"
            Log "backup: $bak"
        }
    }
    Do-It { New-Item -ItemType Junction -Path $Link -Target $Target | Out-Null } "junction $Link -> $Target"
    Log "junction: $Link -> $Target"
}

function Link-File([string]$Target, [string]$Link) {
    $item = Get-Item -LiteralPath $Link -Force -ErrorAction SilentlyContinue
    if ($item) {
        if ((Is-Link $item) -and (@($item.Target) -contains $Target)) {
            Log "ok: $Link já aponta para $Target"; return
        }
        if (Is-Link $item) {
            Do-It { Remove-Item -LiteralPath $Link -Force } "remover o atalho antigo $Link"
        } else {
            $bak = "$Link.bak.$TS"
            Do-It { Move-Item -LiteralPath $Link -Destination $bak } "mover $Link -> $bak"
            Log "backup: $bak"
        }
    }
    if ($DryRun) { Write-Host "[dry-run] link $Link -> $Target"; return }
    try {
        New-Item -ItemType SymbolicLink -Path $Link -Target $Target | Out-Null
        Log "link simbólico: $Link -> $Target"
    } catch {
        try {
            New-Item -ItemType HardLink -Path $Link -Target $Target | Out-Null
            Log "hardlink: $Link -> $Target"
            Warn "hardlink pode se desfazer quando o git reescreve o arquivo. Rode o script de novo se isso acontecer."
        } catch {
            Copy-Item -LiteralPath $Target -Destination $Link
            Warn "não foi possível criar link (ative o Modo de Desenvolvedor ou rode como administrador)."
            Warn "o user.js foi COPIADO: rode este script de novo depois de editá-lo no repositório."
        }
    }
}

function Unlink-Item([string]$Link, [bool]$IsDir) {
    $item = Get-Item -LiteralPath $Link -Force -ErrorAction SilentlyContinue
    if (-not (Is-Link $item)) { Log "nada a desfazer em: $Link (não é link)"; return }
    if ($IsDir) { Do-It { cmd /c rmdir "$Link" | Out-Null } "remover o link $Link" }
    else        { Do-It { Remove-Item -LiteralPath $Link -Force } "remover o link $Link" }
    Log "removido o link: $Link"
    $bak = Latest-Backup $Link
    if ($bak) {
        Do-It { Move-Item -LiteralPath $bak.FullName -Destination $Link } "restaurar $($bak.FullName)"
        Log "restaurado: $($bak.Name) -> $Link"
    }
}

function Check-Private {   # valida ANTES de alterar qualquer coisa
    if (-not (Test-Path -LiteralPath $PrivateDir -PathType Container)) { Die "pasta privada não existe: $PrivateDir" }
    $priv = (Resolve-Path -LiteralPath $PrivateDir).Path.TrimEnd('\') + '\'
    $repo = $Repo.TrimEnd('\') + '\'
    if ($priv.StartsWith($repo, [System.StringComparison]::OrdinalIgnoreCase)) {
        Die "a pasta privada não pode ficar dentro do repositório ($priv)"
    }
    return $priv
}

function Import-Private([string]$Priv) {
    foreach ($f in $PrivateFiles) {
        $src = Join-Path $Priv $f
        $dst = Join-Path $Profile $f
        if (-not (Test-Path -LiteralPath $src)) { Log "pulado (não encontrado): $src"; continue }
        $had = $false
        foreach ($sfx in @('', '-wal', '-shm')) {      # bancos SQLite podem ter -wal/-shm
            $p = "$dst$sfx"
            if (Test-Path -LiteralPath $p) {
                Do-It { Move-Item -LiteralPath $p -Destination "$p.bak.$TS" } "backup $p"
                if ($sfx -eq '') { $had = $true }
            }
        }
        Do-It { Copy-Item -LiteralPath $src -Destination $dst } "copiar $src -> $dst"
        if ($had) { Log "importado: $f (backup do anterior: $f.bak.$TS)" } else { Log "importado: $f" }
    }
    Warn "prefs.js substitui TODAS as preferências do perfil e guarda os IDs das extensões:"
    Warn "em um perfil já usado, extensões podem perder dados locais. Prefira o user.js para preferências."
}

# --- execução ----------------------------------------------------------------
if (-not $Profile) { $Profile = Find-Profile }
if (-not $Profile) { Die "não achei o perfil. Informe com -Profile CAMINHO (veja about:support)." }
if (-not (Test-Path -LiteralPath $Profile -PathType Container)) { Die "pasta do perfil não existe: $Profile" }
$Profile = (Resolve-Path -LiteralPath $Profile).Path

Log "repositório: $Repo"
Log "perfil:      $Profile"
if ($DryRun) { Log "modo dry-run: nada será alterado" }

if ((Get-Process firefox -ErrorAction SilentlyContinue) -and -not $Force) {
    Die "o Firefox está aberto. Feche-o por completo (ou use -Force)."
}

$chromeLink = Join-Path $Profile 'chrome'
$userJsLink = Join-Path $Profile 'user.js'

if ($Undo) {
    Unlink-Item $chromeLink $true
    Unlink-Item $userJsLink $false
    Log "pronto. Os arquivos importados (cert9.db etc.) não são desfeitos: restaure os .bak.* à mão."
    exit 0
}

$priv = $null
if ($ImportPrivate) { $priv = Check-Private }

if (-not (Test-Path (Join-Path $Repo 'firefox-gnome-theme\theme'))) {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        Log "submódulo do tema ausente ou vazio: baixando"
        Do-It { git -C $Repo submodule update --init } "git submodule update --init"
    } else {
        Warn "firefox-gnome-theme está vazio e não achei o git para baixá-lo"
    }
}

Link-Dir $Repo $chromeLink
if (-not $SkipUserJs) {
    $src = Join-Path $Repo 'profile\user.js'
    if (Test-Path -LiteralPath $src) { Link-File $src $userJsLink }
    else { Warn "profile\user.js não existe no repositório; pulando" }
}
if ($ImportPrivate) { Import-Private $priv }

Log "concluído. Abra o Firefox. Para desfazer: .\scripts\link-windows.ps1 -Undo"
