param(
    [string]$FlowUrl,
    [string]$ApiToken,
    [string]$PayloadPath = "$PSScriptRoot\guest-application.test.json"
)

. "$PSScriptRoot\load-env.ps1"

if (-not $FlowUrl -or -not $ApiToken) {
    $envVars = Get-ProjectEnv
    if (-not $FlowUrl) { $FlowUrl = $envVars["FLOW_URL"] }
    if (-not $ApiToken) { $ApiToken = $envVars["API_TOKEN"] }
}

if (-not $FlowUrl -or -not $ApiToken) {
    Write-Error "FLOW_URL and API_TOKEN required. Set them in .env.local (see .env.example) or pass -FlowUrl / -ApiToken."
    exit 1
}

if (-not (Test-Path $PayloadPath)) {
    Write-Error "Payload file not found: $PayloadPath"
    exit 1
}

$payload = Get-Content -Raw -Path $PayloadPath | ConvertFrom-Json
$payload.submittedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$body = $payload | ConvertTo-Json -Depth 5 -Compress
$headers = @{
    "Content-Type" = "application/json"
    "x-api-token" = $ApiToken
}

Write-Host "POST $FlowUrl"
Write-Host $body

try {
    $response = Invoke-WebRequest -Uri $FlowUrl -Method POST -Headers $headers -Body $body -UseBasicParsing
    Write-Host "Status: $($response.StatusCode)"
    Write-Host $response.Content
} catch {
    if ($_.Exception.Response) {
        $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
        $errorBody = $reader.ReadToEnd()
        Write-Host "Status: $($_.Exception.Response.StatusCode.value__)"
        Write-Host $errorBody
    } else {
        Write-Error $_
    }
    exit 1
}
