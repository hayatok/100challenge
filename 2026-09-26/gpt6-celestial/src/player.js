(() => {
  'use strict';
  const film=window.CelestialFilm,canvas=document.querySelector('#screen');
  const playButton=document.querySelector('#play'),replayButton=document.querySelector('#replay'),soundButton=document.querySelector('#sound');
  const slider=document.querySelector('#seek'),timeOutput=document.querySelector('#time'),stageButton=document.querySelector('#stagePlay');
  const status=document.querySelector('#status'),fullButton=document.querySelector('#fullscreen');
  const chapters=[...document.querySelectorAll('[data-time]')];
  const reduced=matchMedia('(prefers-reduced-motion: reduce)');
  let current=0,playing=false,ready=false,started=false,raf=0,anchor=0,offset=0;
  let audioContext=null,audioBuffer=null,source=null,sound=false,audioAnchor=0;
  const bound=n=>Math.max(0,Math.min(film.duration,Number.isFinite(n)?n:0));
  function stopAudio(){if(source){source.onended=null;try{source.stop()}catch{}source.disconnect();source=null}}
  function startAudio(){stopAudio();if(!sound||!audioContext||!audioBuffer||current>=24)return;source=audioContext.createBufferSource();source.buffer=audioBuffer;source.connect(audioContext.destination);source.start(0,current);audioAnchor=audioContext.currentTime-current}
  function show(){
    film.draw(canvas,current);slider.value=current.toFixed(2);slider.setAttribute('aria-valuetext',`${current.toFixed(1)}秒 / 24秒`);
    timeOutput.textContent=`00:${Math.floor(current).toString().padStart(2,'0')} / 00:24`;
    let chapter=film.chapters.findLastIndex(t=>current>=t);chapters.forEach((b,i)=>b.setAttribute('aria-current',i===chapter?'true':'false'));
  }
  function refresh(){playButton.textContent=playing?'一時停止':current>=24?'もう一度再生':'再生';document.querySelector('#fsPlay').textContent=playButton.textContent;stageButton.hidden=playing||started}
  function tick(now){if(!playing)return;current=bound(sound&&audioContext?.state==='running'&&source?audioContext.currentTime-audioAnchor:offset+(now-anchor)/1000);show();if(current>=24){pause();return}raf=requestAnimationFrame(tick)}
  async function play(){
    if(!ready)return;
    if(playing)return;
    if(!started||current>=24)current=0;
    started=true;
    if(sound&&audioContext){try{await audioContext.resume()}catch{sound=false;soundButton.textContent='音：OFF';soundButton.setAttribute('aria-pressed','false');status.textContent='音声を開始できませんでした。映像は再生できます。'}}
    playing=true;anchor=performance.now();offset=current;startAudio();refresh();raf=requestAnimationFrame(tick);
  }
  function pause(){playing=false;cancelAnimationFrame(raf);stopAudio();refresh()}
  function seek(value){current=bound(value);started=true;anchor=performance.now();offset=current;if(playing)startAudio();show();refresh();if(current>=24)pause()}
  playButton.addEventListener('click',()=>playing?pause():play());
  stageButton.addEventListener('click',play);
  document.querySelector('#fsPlay').addEventListener('click',()=>playing?pause():play());
  document.querySelector('#fsExit').addEventListener('click',()=>document.exitFullscreen().catch(()=>{status.textContent='全画面表示を終了できませんでした。Escキーをお試しください。'}));
  replayButton.addEventListener('click',()=>{pause();seek(0);play()});
  slider.addEventListener('input',()=>seek(Number(slider.value)));
  for(const chapter of chapters)chapter.addEventListener('click',()=>{pause();seek(Number(chapter.dataset.time))});
  soundButton.addEventListener('click',async()=>{
    soundButton.disabled=true;
    try{
      if(!audioContext){const Audio=window.AudioContext||window.webkitAudioContext;if(!Audio)throw new Error('unsupported');audioContext=new Audio();await audioContext.resume();const score=CelestialScore.synthesize(audioContext.sampleRate);audioBuffer=audioContext.createBuffer(2,score.left.length,score.sampleRate);audioBuffer.copyToChannel(score.left,0);audioBuffer.copyToChannel(score.right,1)}
      await audioContext.resume();sound=!sound;soundButton.setAttribute('aria-pressed',String(sound));soundButton.textContent=sound?'音：ON':'音：OFF';
      anchor=performance.now();offset=current;if(playing)startAudio();else stopAudio();
      status.textContent=sound?'オリジナルのシンセ音を有効にしました。':'音をオフにしました。';
    }catch{status.textContent='この環境では音声を有効にできません。映像はそのまま再生できます。';sound=false;soundButton.setAttribute('aria-pressed','false');soundButton.textContent='音：OFF'}
    finally{soundButton.disabled=false}
  });
  fullButton.addEventListener('click',async()=>{try{if(document.fullscreenElement)await document.exitFullscreen();else {await document.querySelector('#film').requestFullscreen();document.querySelector('#film').focus()}}catch{status.textContent='このブラウザでは全画面表示を利用できません。'}});
  document.addEventListener('fullscreenchange',()=>{fullButton.textContent=document.fullscreenElement?'全画面を終了':'全画面';refresh()});
  document.addEventListener('keydown',e=>{
    if(!ready||e.ctrlKey||e.metaKey||e.altKey||e.target.matches('button,input,a'))return;
    if(e.code==='Space'){e.preventDefault();playing?pause():play()}
    if(e.code==='ArrowRight'||e.code==='ArrowLeft'){e.preventDefault();seek(current+(e.code==='ArrowRight'?1:-1))}
  });
  document.addEventListener('visibilitychange',()=>{if(document.hidden&&playing){pause();status.textContent='画面が非表示になったため一時停止しました。'}});
  reduced.addEventListener('change',e=>{if(e.matches)pause()});
  const observer=new ResizeObserver(()=>{const width=canvas.clientWidth;const resolution=width<640?1280:1920;if(canvas.width!==resolution){canvas.width=resolution;canvas.height=resolution*9/16;if(ready)show()}});observer.observe(canvas);
  window.teaser={seek,pause,play,get state(){return{time:current,playing,ready,sound,duration:24,audioState:audioContext?.state??'not-created',audioActive:!!source}}};
  async function init(){
    try{await Promise.all([document.fonts.load('700 100px Celestial'),document.fonts.load('400 24px Celestial')]);await document.fonts.ready;ready=true;
      const param=new URLSearchParams(location.search).get('t');
      if(param!==null){current=bound(Number(param));started=true}else current=1.8;
      document.querySelector('#loading').hidden=true;for(const b of [playButton,replayButton,soundButton,fullButton])b.disabled=false;
      show();refresh();if(reduced.matches)status.textContent='動きを減らす設定に合わせ、自動再生は行いません。再生ボタンで開始できます。';
    }catch{document.querySelector('#loading').textContent='読み込みに失敗しました。ページを開き直してください。';status.textContent='埋め込みフォントを読み込めませんでした。'}
  }
  init();
})();
