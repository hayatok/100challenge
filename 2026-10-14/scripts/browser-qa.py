"""Exercise the exported game using real browser keyboard and menu input."""
import argparse
import json
import math
import os
import time
from pathlib import Path
from playwright.sync_api import sync_playwright

parser=argparse.ArgumentParser()
parser.add_argument('--url',default='http://127.0.0.1:4184/?qa=1')
parser.add_argument('--headless',action='store_true')
parser.add_argument('--out',type=Path,default=Path(__file__).resolve().parent.parent/'docs/verification')
args=parser.parse_args()
out=args.out
out.mkdir(parents=True,exist_ok=True)

with sync_playwright() as p:
    headless=args.headless or not os.environ.get('DISPLAY')
    gpu=['--use-gl=angle','--use-angle=swiftshader','--enable-unsafe-swiftshader'] if headless else ['--use-gl=angle','--use-angle=gl','--ignore-gpu-blocklist']
    browser=p.chromium.launch(executable_path=os.environ.get('CHROMIUM_BIN','/usr/bin/chromium'),headless=headless,args=['--no-sandbox',*gpu])
    context=browser.new_context(viewport={'width':1280,'height':720})
    page=context.new_page()
    errors=[]
    page.on('pageerror',lambda error:errors.append(str(error)))
    page.on('console',lambda message:errors.append(message.text) if message.type=='error' else None)
    page.goto(args.url,wait_until='domcontentloaded',timeout=90000)
    page.wait_for_function('window.__taikin && window.__taikin.mode === "title"',timeout=90000)
    page.wait_for_timeout(1000)
    page.screenshot(path=str(out/'cloud-title.png'))
    page.keyboard.press('Enter')
    page.wait_for_function('window.__taikin.mode === "playing"')
    page.keyboard.down('Space')
    page.wait_for_function('window.__taikin.pressure < 72 && window.__taikin.speed > 3')
    page.keyboard.up('Space')
    page.keyboard.press('Escape')
    page.wait_for_function('window.__taikin.mode === "paused"')
    page.wait_for_timeout(300)
    paused=page.evaluate('window.__taikin')
    page.wait_for_timeout(700)
    still=page.evaluate('window.__taikin')
    assert abs(paused['pressure']-still['pressure'])<0.01,'Pressure changed during pause'
    assert abs(paused['elapsed']-still['elapsed'])<0.001,'Timer changed during pause'
    assert all(abs(a-b)<0.001 for a,b in zip(paused['player'],still['player'])),'Chair moved during pause'
    page.screenshot(path=str(out/'cloud-pause.png'))
    page.keyboard.press('Escape')
    page.wait_for_function('window.__taikin.mode === "playing"')
    page.keyboard.press('r')
    page.wait_for_function('window.__taikin.elapsed === 0 && window.__taikin.damage === 0 && window.__taikin.pressure === 100')
    restart=page.evaluate('window.__taikin')
    assert abs(restart['player'][2]-42)<0.01 and restart['broken']==0

    # Follow the same visible office route using controls; never teleport or
    # modify game state. Feedback is read through an opt-in QA-only snapshot.
    targets=[(-0.9,32),(1.0,29),(0,16),(4,-4),(4,-12),(-2,-24),(-2,-32),(0,-48),(0,-58),(0,-61),(0,-64)]
    target=0
    held=set()
    recovering=False
    first_image=False
    start=time.monotonic()
    samples=[]
    while time.monotonic()-start<180:
        state=page.evaluate('window.__taikin')
        if state['mode']=='result':
            break
        assert state['mode']=='playing',f"Unexpected state {state['mode']}"
        x,_,z=state['player']
        # Approach the opening from in front. A low-FPS feedback delay can
        # overshoot to the outside of a pillar; recover with ordinary controls.
        if target>=len(targets)-2 and abs(x)>2.0 and z<-60.5:
            target=len(targets)-3
        tx,tz=targets[target]
        distance=math.hypot(tx-x,tz-z)
        clearance=1.3 if target>=len(targets)-3 else 5.0
        arrival=1.2 if target>=len(targets)-3 else 2.2
        if target<len(targets)-1 and (distance<arrival or (z<tz+0.5 and abs(x-tx)<clearance)):
            target+=1
            tx,tz=targets[target]
        desired=math.atan2(-(tx-x),-(tz-z))
        error=(desired-state['yaw']+math.pi)%(2*math.pi)-math.pi
        keys=set()
        if error>0.085:keys.add('ArrowLeft')
        elif error<-.085:keys.add('ArrowRight')
        if state['pressure']<18:recovering=True
        if state['pressure']>86:recovering=False
        if not recovering and not (abs(error)>.55 and state['speed']>4):keys.add('Space')
        for key in held-keys:page.keyboard.up(key)
        for key in keys-held:page.keyboard.down(key)
        held=keys
        if not first_image and state['max_combo']>=3:
            page.screenshot(path=str(out/'cloud-play.png'))
            first_image=True
        if len(samples)==0 or state['elapsed']-samples[-1]['elapsed']>2:
            samples.append(state)
            print(json.dumps({'pilot':state},ensure_ascii=False),flush=True)
        page.wait_for_timeout(100)
    for key in held:page.keyboard.up(key)
    page.wait_for_timeout(500)
    result=page.evaluate('window.__taikin')
    assert result['mode']=='result',f"Did not reach the elevator: {result}"
    assert result['damage']>0 and result['max_combo']>=3,'Destruction chain was not exercised'
    assert result['best_time']>0,'Successful run was not saved'
    page.screenshot(path=str(out/'cloud-result.png'))
    page.set_viewport_size({'width':1920,'height':1080})
    page.wait_for_timeout(500)
    page.screenshot(path=str(out/'cloud-result-1080.png'))
    page.set_viewport_size({'width':960,'height':540})
    page.wait_for_timeout(400)
    page.screenshot(path=str(out/'cloud-result-compact.png'))
    page.set_viewport_size({'width':1280,'height':720})
    page.reload(wait_until='domcontentloaded')
    page.wait_for_function('window.__taikin && window.__taikin.mode === "title"',timeout=90000)
    reloaded=page.evaluate('window.__taikin')
    assert abs(reloaded['best_time']-result['best_time'])<0.01,'Best time did not survive reload'
    # Use the settings menu and its real OptionButton/sliders.
    page.wait_for_timeout(800)
    page.mouse.click(140,595)
    page.wait_for_timeout(800)
    page.mouse.click(741,258)
    page.wait_for_timeout(800)
    page.mouse.click(741,362)
    page.wait_for_function('window.__taikin.quality === "控えめ"')
    page.mouse.click(421,366)
    page.mouse.click(421,464)
    page.wait_for_function('window.__taikin.music_volume <= 0.01 && window.__taikin.sfx_volume <= 0.01')
    settings=page.evaluate('window.__taikin')
    page.screenshot(path=str(out/'cloud-settings.png'))
    page.mouse.click(640,544)
    page.keyboard.press('Enter')
    page.wait_for_function('window.__taikin.mode === "playing"')
    page.keyboard.down('Space')
    page.wait_for_function('window.__taikin.pressure < 90')
    page.keyboard.up('Space')
    # Focus loss must require explicit resume and leave the chair/time frozen.
    # Playwright otherwise forces document.hasFocus() true on every page.
    context.new_cdp_session(page).send('Emulation.setFocusEmulationEnabled',{'enabled':False})
    other=page.context.new_page()
    other.goto('about:blank')
    context.new_cdp_session(other).send('Emulation.setFocusEmulationEnabled',{'enabled':False})
    other.bring_to_front()
    page.wait_for_function('window.__taikin.mode === "paused"',timeout=10000,polling=100)
    blur_before=page.evaluate('window.__taikin')
    page.wait_for_timeout(500)
    blur_after=page.evaluate('window.__taikin')
    assert abs(blur_before['pressure']-blur_after['pressure'])<0.01 and abs(blur_before['elapsed']-blur_after['elapsed'])<0.001
    other.close()
    page.bring_to_front()
    page.keyboard.press('Escape')
    page.wait_for_function('window.__taikin.mode === "playing"')
    assert not errors,f'Browser errors: {errors}'
    renderer=page.evaluate('''() => { const gl=document.querySelector('canvas').getContext('webgl2'); const e=gl.getExtension('WEBGL_debug_renderer_info'); return e ? gl.getParameter(e.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER); }''')
    report={'browser':browser.version,'renderer':renderer,'viewport':[1280,720],'result':result,'pause_before':paused,'pause_after':still,'restart':restart,'reload_best':reloaded['best_time'],'settings':settings,'blur_before':blur_before,'blur_after':blur_after,'errors':errors,'samples':samples}
    (out/'browser-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
    print(json.dumps({'PASS':True,'result':result,'errors':errors},ensure_ascii=False),flush=True)
    browser.close()
