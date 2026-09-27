import { describe, expect, it } from 'vitest'
import { makeCelestial, parseProject } from '../src/domain/project'
import { compile } from '../src/engine/timeline'
import { direct } from '../src/director/recipes'
import { historyReducer, initialHistory } from '../src/domain/history'
import { standaloneHtml } from '../src/export/html'
import { unsupportedGlyphs } from '../src/engine/render'
import { displayLines } from '../src/engine/text'
describe('project boundary and edit contract',()=>{
  it('compiles the editable CELESTIAL to 24 seconds and 720 frames',()=>{const p=makeCelestial(),tl=compile(p);expect(tl.total).toBe(24);expect(tl.frames).toBe(720);expect(tl.scenes.map(s=>s.start)).toEqual([0,4,8,14,18,20])})
  it('rejects a dangling transition and an out-of-range focus',()=>{const p=makeCelestial();p.scenes[1].outgoing={kind:'circle-match',durationTicks:960};expect(()=>parseProject(p)).toThrow();p.scenes[1].outgoing={kind:'cut',durationTicks:0};p.scenes[5].motion={kind:'particle-lockup',motif:'celestial',intensity:.8,focusGrapheme:20};expect(()=>parseProject(p)).toThrow()})
  it('keeps Japanese input across recipes and undo',()=>{const lines=['ひらめきを','動かそう','言葉が、映像になる'];const a=direct(lines,'celestial'),b=direct(lines,'rhythm');expect(a.scenes.map(s=>s.content.headline)).toEqual(lines);expect(b.scenes.map(s=>s.motion.kind)).not.toEqual(a.scenes.map(s=>s.motion.kind));const h=historyReducer(initialHistory(a),{type:'edit',project:b});expect(historyReducer(h,{type:'undo'}).present).toEqual(a)})
  it('breaks Japanese at a readable phrase boundary',()=>{expect(displayLines('言葉が映像になる','landscape')).toEqual(['言葉が','映像になる'])})
  it('warns when a bundled font lacks a glyph',()=>{const p=makeCelestial();p.scenes[1].content.headline='ASTRA 🛸';expect(unsupportedGlyphs(p)).toContain('🛸')})
  it('escapes hostile project text in standalone HTML',()=>{const p=makeCelestial();p.name='</script><script>window.pwned=1</script>';const html=standaloneHtml(p);expect(html).not.toContain('</script><script>window.pwned');expect(html).toContain('\\u003c/script\\u003e')})
})
describe('audio timeline',()=>{
  it('keeps PCM finite and bound to the compiled duration',async()=>{const { synthesize }=await import('../src/audio/score');const p=makeCelestial(),pcm=synthesize(p,48000);expect(pcm.left.length).toBe(24*48000);expect(pcm.peak).toBeGreaterThan(0);expect(pcm.peak).toBeLessThan(1);expect(pcm.left.every(Number.isFinite)).toBe(true);expect(Math.abs(pcm.left.at(-1)??0)).toBeLessThan(.001);p.bpm=123;const changed=synthesize(p,48000);expect(changed.left.length).toBe(Math.ceil(Math.ceil(compile(p).total*30)/30*48000));expect(changed.left.length).not.toBe(pcm.left.length)})
})
