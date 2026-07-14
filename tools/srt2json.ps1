# Convert all .srt files in assets/videos/ to .json
$srtDir = Join-Path (Join-Path (Join-Path $PSScriptRoot "..") "assets") "videos"
$srtFiles = Get-ChildItem -Path $srtDir -Filter "*.srt"

foreach ($srt in $srtFiles) {
    $content = Get-Content $srt.FullName -Raw -Encoding UTF8
    $content = $content -replace "`r`n", "`n"
    $blocks = $content.Trim() -split "`n`n"

    $entries = @()
    foreach ($block in $blocks) {
        $lines = $block -split "`n"
        # Find timestamp line (contains -->)
        $tsIdx = -1
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match "-->") { $tsIdx = $i; break }
        }
        if ($tsIdx -lt 0) { continue }

        $parts = $lines[$tsIdx] -split "-->"
        if ($parts.Count -ne 2) { continue }

        # Parse HH:MM:SS,mmm to float seconds
        function Parse-Time($t) {
            $t = $t.Replace(",", ".")
            $segments = $t.Trim() -split ":"
            $sp = $segments[2] -split "\."
            $ms = 0
            if ($sp.Count -gt 1) { $ms = [int]$sp[1] }
            return [float]([int]$segments[0]*3600 + [int]$segments[1]*60 + [int]$sp[0]) + $ms/1000.0
        }

        $start = Parse-Time $parts[0]
        $end   = Parse-Time $parts[1]
        if ($start -lt 0 -or $end -lt 0) { continue }

        # Collect text lines after timestamp
        $textLines = @()
        for ($i = $tsIdx + 1; $i -lt $lines.Count; $i++) {
            $line = $lines[$i].Trim()
            if ($line) { $textLines += $line }
        }
        if ($textLines.Count -eq 0) { continue }

        $entries += @{
            start = $start
            end   = $end
            text  = ($textLines -join "`n")
        }
    }

    if ($entries.Count -eq 0) {
        Write-Warning "No entries found in $($srt.Name)"
        continue
    }

    $jsonPath = [System.IO.Path]::ChangeExtension($srt.FullName, ".json")
    $json = $entries | ConvertTo-Json -Depth 3
    Set-Content -Path $jsonPath -Value $json -Encoding UTF8
    Write-Host "$($srt.Name) -> $([System.IO.Path]::GetFileName($jsonPath)) ($($entries.Count) entries)"
}
Write-Host "Done."
