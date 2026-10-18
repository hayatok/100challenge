import { describe, expect, it } from 'vitest'
import { formatTime, makeOutputFileName, parseTime, rangeToFrames, selectionError } from '../src/audio/time'
import { buildPeaks } from '../src/audio/waveform'

describe('選択範囲と時刻', () => {
  it('表示値を再入力してもミリ秒を保ち、繰上がりも正しい', () => {
    for (const seconds of [0, 0.02, 1.234, 59.9996, 60, 599.125]) {
      expect(parseTime(formatTime(seconds))).toBeCloseTo(Math.round(seconds * 1000) / 1000, 6)
    }
    expect(formatTime(59.9996)).toBe('01:00.000')
    expect(parseTime('12.345')).toBe(12.345)
  })
  it('編集中や曖昧な時刻を数値に変換しない', () => {
    for (const value of ['', '1:', '00:60', '1.2.3', '-1', 'Infinity', '01:10.1234']) expect(parseTime(value)).toBeNull()
    expect(selectionError(null, 3, 8)).toContain('入力')
  })
  it('逆転・ゼロ幅・範囲外を拒否し、全範囲末尾の表示丸めだけ許容する', () => {
    expect(selectionError(4, 2, 8)).toBeTruthy()
    expect(selectionError(2, 2, 8)).toBeTruthy()
    expect(selectionError(0, 0.019, 8)).toBeTruthy()
    expect(selectionError(0, 0.02, 8)).toBeNull()
    expect(selectionError(-1, 2, 8)).toBeTruthy()
    expect(selectionError(0, 8.001, 8)).toBeTruthy()
    expect(selectionError(0, 8.001, 8.0007)).toBeNull()
    expect(selectionError(NaN, 8, 8)).toBeTruthy()
  })
  it('同じ境界をPCMのフレームに変換し、末尾をはみ出さない', () => {
    expect(rangeToFrames(1.125, 3.5, 48000, 240000)).toEqual({ first: 54000, last: 168000 })
    expect(rangeToFrames(0, 8.001, 48000, 384034)).toEqual({ first: 0, last: 384034 })
    expect(() => rangeToFrames(1, 0, 48000, 48000)).toThrow()
  })
  it('入力のパス文字や既存の拡張子を保存名へ持ち込まない', () => {
    expect(makeOutputFileName('../メモ:音声.wav', 1, 2.5, 'm4a')).toBe('.._メモ_音声_00-01.000_00-02.500.m4a')
    expect(makeOutputFileName('.wav', 0, 1, 'mp3')).toContain('audio_')
  })
})

describe('実音声の波形', () => {
  it('短いピークと左右逆相の音を失わない', () => {
    const left = new Float32Array([0, 0.8, 0, -0.4])
    const right = new Float32Array([0, -0.8, 0, 0.4])
    expect([...buildPeaks([left, right], 2)]).toEqual([Math.fround(0.8), Math.fround(0.4)])
  })
  it('無音・空・不正サンプルでも有限の波形を返す', () => {
    expect([...buildPeaks([], 3)]).toEqual([0, 0, 0])
    expect([...buildPeaks([new Float32Array([NaN, Infinity, -2])], 3)]).toEqual([0, 0, 1])
  })
})
