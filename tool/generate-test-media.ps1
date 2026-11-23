param(
    [string]$Ffmpeg = 'ffmpeg',
    [string]$OutputDirectory = '.tooling\test-media'
)

$ErrorActionPreference = 'Stop'
$folder = New-Item -ItemType Directory -Force -Path $OutputDirectory
$subtitles = Join-Path $folder.FullName 'test.srt'
@'
1
00:00:02,000 --> 00:00:31,000
AniView QA - embedded subtitle track
'@ | Set-Content -LiteralPath $subtitles -Encoding utf8

$video = Join-Path $folder.FullName 'AniView-QA.mp4'
$encode = @(
    '-hide_banner', '-loglevel', 'error', '-y',
    '-f', 'lavfi', '-i', 'testsrc2=size=480x270:rate=30',
    '-f', 'lavfi', '-i', 'sine=frequency=440:sample_rate=48000', '-i', $subtitles,
    '-map', '0:v:0', '-map', '1:a:0', '-map', '2:s:0', '-t', '34',
    '-c:v', 'libx264', '-pix_fmt', 'yuv420p', '-crf', '24', '-preset', 'fast',
    '-threads', '2', '-g', '60', '-c:a', 'aac', '-af', 'volume=0.18',
    '-c:s', 'mov_text', '-metadata:s:s:0', 'language=eng',
    '-movflags', '+faststart', $video
)
& $Ffmpeg @encode
if ($LASTEXITCODE -ne 0) { throw 'FFmpeg failed to generate the QA MP4.' }

$playlist = Join-Path $folder.FullName 'test.m3u8'
$segments = Join-Path $folder.FullName 'segment-%03d.ts'
$mux = @(
    '-hide_banner', '-loglevel', 'error', '-y', '-i', $video,
    '-map', '0:v:0', '-map', '0:a:0', '-c', 'copy',
    '-f', 'hls', '-hls_time', '4', '-hls_list_size', '0',
    '-hls_playlist_type', 'vod', '-hls_segment_filename', $segments, $playlist
)
& $Ffmpeg @mux
if ($LASTEXITCODE -ne 0) { throw 'FFmpeg failed to generate the QA HLS playlist.' }
Write-Output $folder.FullName
