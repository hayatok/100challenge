/* Original synthesized score. No samples, recordings, downloads or third-party music. */
(() => {
  'use strict';
  const TAU=Math.PI*2;
  function synthesize(sampleRate=44100){
    const duration=24,length=Math.ceil(duration*sampleRate);
    const dry=new Float32Array(length),left=new Float32Array(length),right=new Float32Array(length);
    const add=(at,seconds,fn)=>{const start=Math.round(at*sampleRate),count=Math.ceil(seconds*sampleRate);for(let i=0;i<count&&start+i<length;i++){if(start+i>=0)dry[start+i]+=fn(i/sampleRate,i)}};
    const tone=(at,f,amp,len,bright=.2)=>add(at,len,t=>{const envelope=Math.min(1,t/.006)*Math.exp(-t/(len*.22));return amp*envelope*(Math.sin(TAU*f*t)+bright*Math.sin(TAU*f*2.003*t)+bright*.4*Math.sin(TAU*f*3*t))});
    const bass=[82.4069,65.4064,73.4162,55];
    for(let beat=0;beat<48;beat++){
      const at=beat*.5;
      if(at>=23)continue;
      const lunar=at>=12&&at<14;
      if(at>=2&&!lunar){
        add(at,.27,t=>.19*Math.exp(-t*19)*Math.sin(TAU*(48*t+2.5*(1-Math.exp(-t*28)))));
        tone(at,bass[Math.floor(at/5)%4],lunar?.045:.07,.42,.14);
      }
      if(at>=4&&at<12||at>=18&&at<22){
        // Tick-like closed hats made from deterministic noise.
        for(const offset of [0,.25])add(at+offset,.05,(t,i)=>{const n=Math.sin((i+beat*831)*78.233)*43758.5453;return ((n-Math.floor(n))*2-1)*Math.exp(-t*95)*.025});
      }
      if(beat%2===0||at>=4&&at<8){
        const notes=[329.6276,493.8833,659.2551,739.9888,493.8833,440];
        tone(at,notes[beat%notes.length],lunar?.028:.04,lunar?1.7:1.15,.16);
      }
    }
    // Slow harmonic beds change with the four celestial acts.
    const chords=[[0,[164.814,246.942,329.628]],[4,[164.814,246.942,369.994]],[8,[130.813,196,329.628]],[14,[146.832,220,329.628]],[18,[164.814,246.942,329.628]],[22,[164.814,246.942,329.628]]];
    for(const [at,notes] of chords){const len=at===0?4.8:5;for(const f of notes)add(at,len,t=>{const env=Math.min(1,t/1.2)*Math.min(1,(len-t)/1.2);return .016*env*(Math.sin(TAU*f*t)+.35*Math.sin(TAU*f*1.003*t))})}
    for(const at of [1,2,4,6,8,10,14,18,20,22]){tone(at,82.4069,.11,1.4,.08);tone(at,1318.51,.018,2,.05)}
    // Editorial swells crest at the star flight, solar impact and final lockup.
    for(const at of [5.5,7.5,13.5,17.5,21.5])add(at,.5,(t,i)=>{
      const h=Math.sin((i+at*1000)*91.19)*43758.5453;
      const envelope=Math.sin(Math.PI*t/.5)**2;
      return ((h-Math.floor(h))*2-1)*.025*envelope + Math.sin(TAU*(160*t+700*t*t))*.016*envelope;
    });
    // Snare/clap accents are synthesized; the eclipse intentionally drops the drums.
    for(let beat=5;beat<44;beat+=2){const at=beat*.5;if(at>=12&&at<14)continue;
      add(at,.13,(t,i)=>{const h=Math.sin((i+beat*13)*39.17)*12345.67;return ((h-Math.floor(h))*2-1)*.042*Math.exp(-t*35)});
    }
    for(let i=0;i<length;i++){
      const t=i/sampleRate;
      const fade=Math.min(1,t/.03,Math.max(0,(24-t)/1.1));
      const echoL=i>sampleRate*.1875?dry[i-Math.floor(sampleRate*.1875)]*.24:0;
      const echoR=i>sampleRate*.3125?dry[i-Math.floor(sampleRate*.3125)]*.22:0;
      left[i]=Math.tanh((dry[i]+echoL)*1.25)*.72*fade;
      right[i]=Math.tanh((dry[i]+echoR)*1.25)*.72*fade;
    }
    return{left,right,sampleRate,duration};
  }
  globalThis.CelestialScore={synthesize};
})();
