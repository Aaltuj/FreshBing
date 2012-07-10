# FreshBing
# https://github.com/ndabas/FreshBing

$rssUrl = "http://themeserver.microsoft.com/default.aspx?p=Bing&c=Desktop&m=en-US"
$feed = [xml](New-Object System.Net.WebClient).DownloadString($rssUrl)
$base = [Environment]::GetFolderPath("MyPictures")
$selectedUrl = ""
$selectedFile = ""
$oldFile = ""

# Run through the feed, and find the oldest file that we haven't downloaded yet.
foreach ($item in $feed.rss.channel.item) {
    $url = New-Object System.Uri($item.enclosure.url)
    $file = [System.Uri]::UnescapeDataString($url.Segments[-1])
    $path = Join-Path $base $file
    
    # We have this file, so we need to download the previous file and delete this one
    if (Test-Path $path) {
        $oldFile = $path
        Break
    }
    $selectedUrl = $url
    $selectedFile = $path
}

if (!$selectedUrl) {
    "Nothing to download - we already have the newest file."
    Return
}

"Downloading $selectedUrl -> $selectedFile"
(New-Object System.Net.WebClient).DownloadFile($selectedUrl, $selectedFile)

Add-Type -Namespace FreshBing -Name UnsafeNativeMethods -MemberDefinition @"
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern int SystemParametersInfo (int uAction, int uParam, string lpvParam, int fuWinIni);
"@
$SPI_SETDESKWALLPAPER = 20
$SPIF_UPDATEINIFILE = 0x01
$SPIF_SENDWININICHANGE = 0x02
$result = [FreshBing.UnsafeNativeMethods]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $selectedFile, $SPIF_UPDATEINIFILE -bor $SPIF_SENDWININICHANGE)
# This could fail on Windows XP because it does not support jpg wallpapers natively
if ($result -ne 1) {
    # Convert the file to a bmp and set that as wallpaper
    [Reflection.Assembly]::LoadWithPartialName('System.Drawing')
    
    $image = [Drawing.Image]::FromFile($selectedFile)
    $bmpFile = [System.IO.Path]::ChangeExtension($selectedFile, ".bmp")
    $image.Save($bmpFile, "Bmp")
    $image.Dispose()
    
    [FreshBing.UnsafeNativeMethods]::SystemParametersInfo($SPI_SETDESKWALLPAPER, 0, $bmpFile, $SPIF_UPDATEINIFILE -bor $SPIF_SENDWININICHANGE)
}
Set-ItemProperty -path "HKCU:\Control Panel\Desktop\" -name WallpaperStyle -value 2
Set-ItemProperty -path "HKCU:\Control Panel\Desktop\" -name TileWallpaper -value 0

if ($oldfile -and (Test-Path $oldFile) -and (Test-Path $selectedFile)) {
    Remove-Item $oldFile
    "Deleting $oldFile"
    
    $bmpFile = [System.IO.Path]::ChangeExtension($oldFile, ".bmp")
    if (Test-Path $bmpFile) {
        Remove-Item $bmpFile
        "Deleting $bmpFile"
    }
}
