param(
  [string]$OutputPath = "dist\infrareaper-lambda.zip"
)

$ErrorActionPreference = "Stop"
$root = Resolve-Path (Join-Path $PSScriptRoot "..")
$dist = Join-Path $root "dist"
$lambdaDir = Join-Path $root "lambdas"
$destination = Join-Path $root $OutputPath

New-Item -ItemType Directory -Force $dist | Out-Null
npm.cmd --prefix $lambdaDir install --omit=dev

if (Test-Path $destination) {
  Remove-Item $destination -Force
}

# Stage a clean copy of resource/ without the .terraform directory, which
# contains Windows provider binaries (~685 MB) from local development.
# The Lambda runs terraform init at runtime and downloads its own providers.
$stageDir = Join-Path $dist "lambda-stage"
if (Test-Path $stageDir) { Remove-Item $stageDir -Recurse -Force }
New-Item -ItemType Directory -Force $stageDir | Out-Null

Copy-Item (Join-Path $lambdaDir "src")          (Join-Path $stageDir "src")          -Recurse
Copy-Item (Join-Path $lambdaDir "package.json") (Join-Path $stageDir "package.json")

$resourceSrc  = Join-Path $lambdaDir "resource"
$resourceDest = Join-Path $stageDir  "resource"
New-Item -ItemType Directory -Force $resourceDest | Out-Null
Get-ChildItem $resourceSrc -Exclude ".terraform" | Copy-Item -Destination $resourceDest -Recurse

# Copy node_modules but skip the workspace symlink to the project root.
$nmSrc  = Join-Path $lambdaDir "node_modules"
$nmDest = Join-Path $stageDir  "node_modules"
New-Item -ItemType Directory -Force $nmDest | Out-Null
Get-ChildItem $nmSrc -Exclude "infrareaper" | Copy-Item -Destination $nmDest -Recurse

Push-Location $stageDir
try {
  Compress-Archive -Path src, resource, node_modules, package.json -DestinationPath $destination -Force
}
finally {
  Pop-Location
}

Remove-Item $stageDir -Recurse -Force

Write-Host "Created $destination"

