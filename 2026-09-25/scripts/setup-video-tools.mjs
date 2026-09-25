import { spawnSync } from 'node:child_process'

const available = name => spawnSync(name, ['-version'], { stdio: 'ignore' }).status === 0
if (!available('ffmpeg') || !available('ffprobe')) {
  if (process.platform !== 'linux') {
    throw new Error('動画の検証にはffmpegとffprobeが必要です。両方をインストールしてください。')
  }
  const elevated = process.getuid?.() !== 0
  for (const args of [['update', '-qq'], ['install', '-y', '-qq', 'ffmpeg']]) {
    const result = spawnSync(elevated ? 'sudo' : 'apt-get', elevated ? ['apt-get', ...args] : args, { stdio: 'inherit' })
    if (result.status !== 0) throw new Error(`ffmpegの導入に失敗しました: apt-get ${args[0]}`)
  }
}
if (!available('ffmpeg') || !available('ffprobe')) throw new Error('ffmpegとffprobeを起動できません。')
console.log('Video verification tools ready: ffmpeg, ffprobe')
