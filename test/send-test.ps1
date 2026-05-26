param(
    [Parameter(Mandatory = $true)]
    [string]$FlowUrl,

    [string]$PayloadPath = "$PSScriptRoot\guest-application.test.json"
)

if (-not (Test-Path $PayloadPath)) {
    Write-Error "Payload file not found: $PayloadPath"
    exit 1
}

$payload = Get-Content -Raw -Path $PayloadPath | ConvertFrom-Json
$payload.submittedAt = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$body = $payload | ConvertTo-Json -Depth 5 -Compress

Write-Host "POST $FlowUrl"
Write-Host $body

try {
    $response = Invoke-WebRequest -Uri $FlowUrl -Method POST -ContentType "application/json" -Body $body -UseBasicParsing
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
