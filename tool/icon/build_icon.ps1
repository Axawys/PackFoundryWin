# Rebuilds the PackFoundry icon from tool/icon/make_icon.py:
#   assets/icon.svg, assets/icon.png (1024 px, transparent) and
#   windows/runner/resources/app_icon.ico (16 to 256 px).
# Needs Python and Microsoft Edge, which renders the SVG.
$ErrorActionPreference = 'Stop'
$root = Resolve-Path "$PSScriptRoot\..\.."
$work = Join-Path ([IO.Path]::GetTempPath()) "packfoundry_icon_$PID"
New-Item -ItemType Directory -Force $work | Out-Null

python "$PSScriptRoot\make_icon.py" "$root\assets\icon.svg" | Out-Null

# Edge renders the SVG at 1024 px on a transparent background.
$svg = [IO.File]::ReadAllText("$root\assets\icon.svg")
[IO.File]::WriteAllText("$work\icon.svg", $svg.Replace('width="512" height="512"', 'width="1024" height="1024"'))
[IO.File]::WriteAllText("$work\page.html", "<html><head><style>html,body{margin:0;background:transparent}</style></head><body><img src='icon.svg' width='1024' height='1024'></body></html>")
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") |
  Where-Object { Test-Path $_ } | Select-Object -First 1
$edgeArgs = @('--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
  '--default-background-color=00000000', "--user-data-dir=$work\edge", '--window-size=1024,1024',
  "--screenshot=$root\assets\icon.png", "file:///$($work.Replace('\', '/'))/page.html")
(Start-Process $edge -ArgumentList $edgeArgs -PassThru -WindowStyle Hidden).WaitForExit(60000) | Out-Null

# Each icon size is a high quality downscale of the 1024 px render, stored
# as PNG inside the .ico; 256 is written as 0 in the directory entry.
Add-Type -AssemblyName System.Drawing
$source = New-Object System.Drawing.Bitmap "$root\assets\icon.png"
$sizes = 16, 20, 24, 32, 40, 48, 64, 128, 256
$frames = foreach ($size in $sizes) {
  $bitmap = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $graphics.DrawImage($source, 0, 0, $size, $size)
  $graphics.Dispose()
  $stream = New-Object IO.MemoryStream
  $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
  $bitmap.Dispose()
  , $stream.ToArray()
}
$source.Dispose()

$ico = New-Object IO.MemoryStream
$writer = New-Object IO.BinaryWriter $ico
$writer.Write([UInt16]0); $writer.Write([UInt16]1); $writer.Write([UInt16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
for ($i = 0; $i -lt $sizes.Count; $i++) {
  $dimension = if ($sizes[$i] -ge 256) { 0 } else { $sizes[$i] }
  $writer.Write([byte]$dimension); $writer.Write([byte]$dimension)
  $writer.Write([byte]0); $writer.Write([byte]0)
  $writer.Write([UInt16]1); $writer.Write([UInt16]32)
  $writer.Write([UInt32]$frames[$i].Length); $writer.Write([UInt32]$offset)
  $offset += $frames[$i].Length
}
foreach ($frame in $frames) { $writer.Write($frame) }
[IO.File]::WriteAllBytes("$root\windows\runner\resources\app_icon.ico", $ico.ToArray())

Write-Output "Icon rebuilt: assets\icon.svg, assets\icon.png, windows\runner\resources\app_icon.ico"
