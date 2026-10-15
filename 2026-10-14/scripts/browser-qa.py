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
    def click_control(name, fraction_x=.5, fraction_y=.5):
        state=page.evaluate('window.__taikin.hud')
        x,y,w,h=state['controls'][name]
        sx,sy=state['root_scale']
        ox,oy=state['root_offset']
        canvas=page.locator('canvas').bounding_box()
        vw,vh=state['viewport']
        page.mouse.click(canvas['x']+(ox+(x+w*fraction_x)*sx)*canvas['width']/vw,
                         canvas['y']+(oy+(y+h*fraction_y)*sy)*canvas['height']/vh)
    page.wait_for_timeout(1000)
    page.screenshot(path=str(out/'cloud-title.png'))
    click_control('title_start')
    page.wait_for_function('window.__taikin.mode === "playing"')
    page.keyboard.down('Space')
    page.wait_for_function('window.__taikin.pressure < 72 && window.__taikin.speed > 3')
    boost=page.evaluate('window.__taikin')
    assert boost['fx']['counts']['powder']>0,'Spray has no visible powder batch'
    assert boost['fx']['jet_core_visible'] and boost['fx']['jet_core_length']>0,'Spray has no connected rear jet'
    page.screenshot(path=str(out/'cloud-boost.png'))
    # Keep using the real spray control until the first local destruction.
    # Observe employee motion without triggering poses through the QA channel.
    page.wait_for_function('window.__taikin.office.coworkers.some(p => p.state === "startled" && p.mug_lift > .04)',timeout=20000)
    reaction=page.evaluate('window.__taikin')
    reacting=[person for person in reaction['office']['coworkers'] if person['state']!='sleepy']
    assert 1<=len(reacting)<=2,'Local destruction must wake at most two nearby employees'
    assert all(person['distance']<=12 and person['starts']==1 for person in reacting)
    assert any(person['expression']=='startled' and person['callout'] for person in reacting)
    assert any(person['starts']==0 for person in reaction['office']['coworkers']),'Distant employees all reacted'
    page.screenshot(path=str(out/'cloud-reaction.png'))
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
    for key in ['animation_clock','phase','burst_left','counter_age','damage_age']:
        assert abs(paused['hud'][key]-still['hud'][key])<.001,f'HUD {key} changed during pause'
    for key in ['particle_clock','life_total']:
        assert abs(paused['fx'][key]-still['fx'][key])<.001,f'FX {key} changed during pause'
    assert paused['office']==still['office'],'Employee poses, onset delays or cooldowns changed during pause'
    assert abs(paused['fx']['jet_core_length']-still['fx']['jet_core_length'])<.001,'Jet retracted during pause'
    page.screenshot(path=str(out/'cloud-pause.png'))
    page.keyboard.press('Escape')
    page.wait_for_function('window.__taikin.mode === "playing"')
    page.keyboard.press('r')
    page.wait_for_function('window.__taikin.elapsed === 0 && window.__taikin.damage === 0 && window.__taikin.pressure === 100')
    restart=page.evaluate('window.__taikin')
    assert abs(restart['player'][2]-42)<0.01 and restart['broken']==0
    assert restart['fx']['rush_starts']==0 and restart['hud']['rush_starts']==0 and restart['hud']['success_starts']==0
    assert restart['office']['seen_events']==0 and all(person['starts']==0 and person['state']=='sleepy' for person in restart['office']['coworkers'])
    assert not restart['fx']['jet_core_visible'],'Restart retained the connected jet'

    # Follow the same visible office route using controls; never teleport or
    # modify game state. Feedback is read through an opt-in QA-only snapshot.
    targets=[(0,28),(0,16),(4,-4),(4,-12),(-2,-24),(-2,-32),(0,-48),(0,-58),(0,-61),(0,-64)]
    target=0
    held=set()
    recovering=False
    first_image=False
    start=time.monotonic()
    samples=[]
    employee_reactions=[]
    while time.monotonic()-start<180:
        state=page.evaluate('window.__taikin')
        if state['mode']=='result':
            break
        assert state['mode']=='playing',f"Unexpected state {state['mode']}"
        active=[person for person in state['office']['coworkers'] if person['state']!='sleepy']
        assert len(active)<=2,'More than two employees reacted simultaneously'
        if active and (not employee_reactions or state['elapsed']-employee_reactions[-1]['elapsed']>.3):
            employee_reactions.append({'elapsed':state['elapsed'],'coworkers':state['office']['coworkers']})
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
        # A held key spans whole rendered frames. Leave a wider steering
        # tolerance on the software renderer and approach the door slowly.
        deadband=.12+min(.16,.45/max(1,state['fps']))
        if error>deadband:keys.add('ArrowLeft')
        elif error<-deadband:keys.add('ArrowRight')
        if state['pressure']<18:recovering=True
        if state['pressure']>86:recovering=False
        goal_approach=target>=len(targets)-3
        speed_limit=2.8 if goal_approach else 9.0
        if not recovering and state['speed']<speed_limit and not (abs(error)>.55 and state['speed']>4):keys.add('Space')
        # Finish with spray held, then release on the result: this must never
        # leak through to the newly focused Retry button.
        if target==len(targets)-1 and abs(x)<1.5 and z<-61.2:keys.add('Space')
        for key in held-keys:page.keyboard.up(key)
        for key in keys-held:page.keyboard.down(key)
        held=keys
        if not first_image and state['rush'] and state['hud']['burst_kind']=='rush':
            page.screenshot(path=str(out/'cloud-play.png'))
            first_image=True
        if len(samples)==0 or state['elapsed']-samples[-1]['elapsed']>2:
            samples.append(state)
            print(json.dumps({'pilot':{k:state[k] for k in ['elapsed','player','speed','pressure','damage','max_combo','fps','draw_calls']}},ensure_ascii=False),flush=True)
        page.wait_for_timeout(100)
    for key in held:page.keyboard.up(key)
    page.screenshot(path=str(out/'cloud-success.png'))
    page.wait_for_timeout(500)
    result=page.evaluate('window.__taikin')
    assert result['mode']=='result',f"Did not reach the elevator: {result}"
    assert result['damage']>0 and result['max_combo']>=3,'Destruction chain was not exercised'
    assert result['best_time']>0,'Successful run was not saved'
    assert result['hud']['success_starts']==1,'Success stamp was missing or repeated'
    assert abs(result['actor_yaw'])<.15,'Victory portrait still hides the face at this arrival heading'
    assert result['fx']['rush_starts']==result['hud']['rush_starts'],'World and HUD rush entries diverged'
    assert first_image,'Rush visual was not exercised'
    assert employee_reactions,'Full run did not exercise nearby employee responses'
    page.screenshot(path=str(out/'cloud-result.png'))
    page.set_viewport_size({'width':1920,'height':1080})
    page.wait_for_timeout(500)
    page.screenshot(path=str(out/'cloud-result-1080.png'))
    page.set_viewport_size({'width':960,'height':540})
    page.wait_for_timeout(400)
    page.screenshot(path=str(out/'cloud-result-compact.png'))
    page.set_viewport_size({'width':1280,'height':720})
    page.wait_for_timeout(1000)
    click_control('result_retry')
    page.wait_for_function('window.__taikin.mode === "playing" && window.__taikin.elapsed === 0')
    retry_button=page.evaluate('window.__taikin')
    assert retry_button['fx']['particles']==0 and retry_button['hud']['success_starts']==0,'Result retry retained previous effects'
    assert retry_button['office']['seen_events']==0 and all(person['starts']==0 and person['expression']=='sleepy' for person in retry_button['office']['coworkers'])
    assert not retry_button['fx']['jet_core_visible'],'Result retry retained the live jet'
    page.reload(wait_until='domcontentloaded')
    page.wait_for_function('window.__taikin && window.__taikin.mode === "title"',timeout=90000)
    reloaded=page.evaluate('window.__taikin')
    assert abs(reloaded['best_time']-result['best_time'])<0.01,'Best time did not survive reload'
    # Use the settings menu and its real OptionButton/sliders.
    page.wait_for_timeout(800)
    click_control('title_settings')
    page.wait_for_timeout(800)
    page.wait_for_function('window.__taikin.hud.settings_visible')
    click_control('settings_quality')
    page.wait_for_timeout(800)
    # A freshly opened PopupMenu has no highlighted row. Traverse all three
    # real items rather than relying on a platform-specific End shortcut.
    page.keyboard.press('ArrowDown')
    page.wait_for_timeout(150)
    page.keyboard.press('ArrowDown')
    page.wait_for_timeout(150)
    page.keyboard.press('ArrowDown')
    page.wait_for_timeout(150)
    page.keyboard.press('Enter')
    page.wait_for_function('window.__taikin.quality === "控えめ"')
    click_control('settings_music',0.02)
    click_control('settings_sfx',0.02)
    page.wait_for_function('window.__taikin.music_volume <= 0.01 && window.__taikin.sfx_volume <= 0.01')
    settings=page.evaluate('window.__taikin')
    page.screenshot(path=str(out/'cloud-settings.png'))
    click_control('settings_close')
    page.wait_for_function('!window.__taikin.hud.settings_visible')
    click_control('title_start')
    page.wait_for_function('window.__taikin.mode === "playing"')
    page.keyboard.down('Space')
    page.wait_for_function('window.__taikin.pressure < 90')
    subdued=page.evaluate('window.__taikin')
    assert subdued['fx']['particles']<=20 and subdued['fx']['counts']['streak']==0
    assert subdued['hud']['combo_scale']==[1,1] and subdued['hud']['damage_scale']==[1,1],'Subdued UI still bounces'
    assert subdued['office']['quality']=='控えめ' and all(person['quality']=='控えめ' for person in subdued['office']['coworkers'])
    assert subdued['fx']['jet_core_visible'] and subdued['fx']['jet_core_length']<boost['fx']['jet_core_length'],'Subdued must retain a smaller connected jet'
    page.screenshot(path=str(out/'cloud-subdued.png'))
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
    assert abs(blur_before['hud']['animation_clock']-blur_after['hud']['animation_clock'])<.001
    assert abs(blur_before['fx']['particle_clock']-blur_after['fx']['particle_clock'])<.001
    assert blur_before['office']==blur_after['office'],'Focus loss did not freeze employee response clocks'
    other.close()
    page.bring_to_front()
    page.keyboard.press('Escape')
    page.wait_for_function('window.__taikin.mode === "playing"')
    assert not errors,f'Browser errors: {errors}'
    renderer=page.evaluate('''() => { const gl=document.querySelector('canvas').getContext('webgl2'); const e=gl.getExtension('WEBGL_debug_renderer_info'); return e ? gl.getParameter(e.UNMASKED_RENDERER_WEBGL) : gl.getParameter(gl.RENDERER); }''')
    report={'browser':browser.version,'renderer':renderer,'viewport':[1280,720],'boost':boost,'reaction':reaction,'employee_reactions':employee_reactions,'result':result,'pause_before':paused,'pause_after':still,'restart':restart,'retry_button':retry_button,'reload_best':reloaded['best_time'],'settings':settings,'subdued':subdued,'blur_before':blur_before,'blur_after':blur_after,'errors':errors,'samples':samples}
    (out/'browser-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2))
    print(json.dumps({'PASS':True,'result':result,'errors':errors},ensure_ascii=False),flush=True)
    browser.close()
