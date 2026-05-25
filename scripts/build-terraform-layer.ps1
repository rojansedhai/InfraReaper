param(
  [string]$Version = "1.13.4",
  [string]$OutputPath = "dist\terraform-layer.zip"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$dist = Join-Path $root "dist"
$workDir = Join-Path $dist "terraform-layer"
$terraformZip = Join-Path $dist "terraform-linux-amd64.zip"
$destination = Join-Path $root $OutputPath
$downloadUrl = "https://releases.hashicorp.com/terraform/$Version/terraform_${Version}_linux_amd64.zip"

New-Item -ItemType Directory -Force (Join-Path $workDir "bin") | Out-Null
Invoke-WebRequest -Uri $downloadUrl -OutFile $terraformZip
Expand-Archive -Path $terraformZip -DestinationPath (Join-Path $workDir "bin") -Force

if (Test-Path $destination) {
  Remove-Item $destination -Force
}

Push-Location $workDir
try {
  Compress-Archive -Path bin -DestinationPath $destination -Force
}
finally {
  Pop-Location
}

Write-Host "Created $destination"

