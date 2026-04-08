param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("fibonacci_vga", "sorting_vga")]
    [string]$Program,

    [Parameter(Mandatory = $false)]
    [string]$ToolPrefix,

    [Parameter(Mandatory = $false)]
    [string]$VvpOut = "program_test.vvp"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

$buildScript = Join-Path $projectRoot "scripts/build_program_image.ps1"
if (-not (Test-Path $buildScript)) {
    throw "Missing script: $buildScript"
}

$buildArgs = @{
    Program = $Program
    OutputInst = "inst.txt"
}
if ($ToolPrefix) {
    $buildArgs.ToolPrefix = $ToolPrefix
}

& $buildScript @buildArgs

$iverilog = (Get-Command iverilog -ErrorAction SilentlyContinue)
$vvp = (Get-Command vvp -ErrorAction SilentlyContinue)
if (-not $iverilog -or -not $vvp) {
    throw "iverilog/vvp not found. Please install Icarus Verilog first."
}

$iverilogArgs = @(
    "-o", $VvpOut,
    "-y", "rtl/core",
    "-y", "rtl/utils",
    "-y", "rtl/hazard",
    "-y", "rtl/top",
    "-y", "fpga",
    "-I", "rtl/include",
    "-I", "rtl/utils",
    "-I", "rtl/top",
    "-I", "rtl/core",
    "-I", "fpga",
    "-D", "DMEM_INIT",
    "tb/system_full_tb.v"
)

& $iverilog.Source @iverilogArgs
if ($LASTEXITCODE -ne 0) { throw "iverilog compile failed" }

& $vvp.Source $VvpOut
if ($LASTEXITCODE -ne 0) { throw "vvp run failed" }
