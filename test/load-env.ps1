function Import-EnvFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return @{}
    }

    $vars = @{}

    Get-Content -Path $Path | ForEach-Object {
        $line = $_.Trim()
        if ($line -eq "" -or $line.StartsWith("#")) {
            return
        }

        $separatorIndex = $line.IndexOf("=")
        if ($separatorIndex -lt 1) {
            return
        }

        $key = $line.Substring(0, $separatorIndex).Trim()
        $value = $line.Substring($separatorIndex + 1).Trim()

        if ($value.StartsWith('"') -and $value.EndsWith('"')) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        $vars[$key] = $value
    }

    return $vars
}

function Get-ProjectEnv {
    param(
        [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
    )

    $merged = @{}

    foreach ($fileName in @(".env", ".env.local")) {
        $filePath = Join-Path $ProjectRoot $fileName
        $fileVars = Import-EnvFile -Path $filePath
        foreach ($key in $fileVars.Keys) {
            $merged[$key] = $fileVars[$key]
        }
    }

    return $merged
}
