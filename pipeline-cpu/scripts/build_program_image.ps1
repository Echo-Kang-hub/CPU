param(
    [Parameter(Mandatory = $false)]
    [ValidateSet("fibonacci_vga", "sorting_vga")]
    [string]$Program,

    [Parameter(Mandatory = $false)]
    [string]$AsmPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputInst = "inst.txt",

    [Parameter(Mandatory = $false)]
    [string]$ToolPrefix
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-Tool {
    param(
        [string[]]$Candidates
    )

    foreach ($name in $Candidates) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
    }
    return $null
}

function Convert-BinaryToInst {
    param(
        [string]$BinaryPath,
        [string]$InstPath
    )

    $bytes = [System.IO.File]::ReadAllBytes($BinaryPath)
    $words = New-Object System.Collections.Generic.List[string]

    $count = $bytes.Length
    $aligned = [Math]::Ceiling($count / 4.0) * 4

    for ($i = 0; $i -lt $aligned; $i += 4) {
        $b0 = if ($i -lt $count) { $bytes[$i] } else { 0 }
        $b1 = if (($i + 1) -lt $count) { $bytes[$i + 1] } else { 0 }
        $b2 = if (($i + 2) -lt $count) { $bytes[$i + 2] } else { 0 }
        $b3 = if (($i + 3) -lt $count) { $bytes[$i + 3] } else { 0 }

        $word = [uint32]($b0 -bor ($b1 -shl 8) -bor ($b2 -shl 16) -bor ($b3 -shl 24))
        $words.Add(('{0:X8}' -f $word))
    }

    [System.IO.File]::WriteAllLines($InstPath, $words)
}

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

if (-not $AsmPath) {
    if (-not $Program) {
        throw "Please provide -Program (fibonacci_vga|sorting_vga) or -AsmPath."
    }
    $AsmPath = Join-Path $projectRoot ("asm/{0}.asm" -f $Program)
}

$AsmPath = (Resolve-Path $AsmPath).Path
$OutputInst = Join-Path $projectRoot $OutputInst

if (-not (Test-Path $AsmPath)) {
    throw "Assembly file not found: $AsmPath"
}

# 自动探测工具链
if (-not $ToolPrefix) {
    $knownPrefixes = @(
        "riscv32-unknown-elf",
        "riscv64-unknown-elf",
        "riscv-none-elf"
    )

    foreach ($prefix in $knownPrefixes) {
        $asPath = Resolve-Tool -Candidates @("$prefix-as")
        $ldPath = Resolve-Tool -Candidates @("$prefix-ld")
        $objcopyPath = Resolve-Tool -Candidates @("$prefix-objcopy")
        if ($asPath -and $ldPath -and $objcopyPath) {
            $ToolPrefix = $prefix
            break
        }
    }
}

if (-not $ToolPrefix) {
    throw @"
No supported RISC-V GNU toolchain was detected.
Install one of the following and add it to PATH:
- riscv32-unknown-elf-as/ld/objcopy
- riscv64-unknown-elf-as/ld/objcopy
- riscv-none-elf-as/ld/objcopy
"@
}

$asExe = Resolve-Tool -Candidates @("$ToolPrefix-as")
$ldExe = Resolve-Tool -Candidates @("$ToolPrefix-ld")
$objcopyExe = Resolve-Tool -Candidates @("$ToolPrefix-objcopy")

if (-not $asExe -or -not $ldExe -or -not $objcopyExe) {
    throw "Toolchain prefix '$ToolPrefix' is incomplete. as/ld/objcopy must all be available."
}

$tmpDir = Join-Path $projectRoot "temp/.build_image"
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null

$objPath = Join-Path $tmpDir "program.o"
$elfPath = Join-Path $tmpDir "program.elf"
$binPath = Join-Path $tmpDir "program.bin"
$linkerPath = Join-Path $tmpDir "link.ld"

@"
SECTIONS {
  . = 0x00000000;
  .text : { *(.text*) }
  .rodata : { *(.rodata*) }
  .data : { *(.data*) }
  .bss : { *(.bss*) }
}
"@ | Set-Content -NoNewline -Path $linkerPath

& $asExe "-march=rv32i" "-mabi=ilp32" "-o" $objPath $AsmPath
if ($LASTEXITCODE -ne 0) { throw "Assembly failed: $AsmPath" }

& $ldExe "-m" "elf32lriscv" "-T" $linkerPath "-o" $elfPath $objPath
if ($LASTEXITCODE -ne 0) { throw "Link failed: $AsmPath" }

& $objcopyExe "-O" "binary" $elfPath $binPath
if ($LASTEXITCODE -ne 0) { throw "Objcopy failed: $AsmPath" }

Convert-BinaryToInst -BinaryPath $binPath -InstPath $OutputInst

Write-Host "Generated instruction image: $OutputInst"
Write-Host "Source assembly: $AsmPath"
Write-Host "Toolchain prefix: $ToolPrefix"
