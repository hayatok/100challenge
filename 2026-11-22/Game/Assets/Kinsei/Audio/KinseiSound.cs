using System.Collections.Generic;
using UnityEngine;

// Original offline score and bounded cue voices. No runtime synthesis/allocation in Update.
public sealed class KinseiSound : MonoBehaviour
{
    public static float MusicGain = .72f;
    public static float SfxGain = .8f;
    public static float AmbientGain = .3f;
    AudioSource music, room, stageVoice;
    readonly AudioSource[] floorSpeakers=new AudioSource[2];
    readonly AudioSource[] voices = new AudioSource[6];
    readonly Dictionary<string, AudioClip[]> clips = new();
    readonly Dictionary<string, float> lastCue = new();
    readonly Dictionary<string, int> variant = new();
    bool paused, unfocused, dialogue;
    bool stageQuiet;
    public float MusicSeconds => music && music.clip ? (float)music.timeSamples/music.clip.frequency : 0;
    public void SetMorningRequest(bool onAir)
    {
        string resource=onAir ? "sakai-morning" : "kinsei-waltz";
        if(music.clip && music.clip.name==resource)return;
        StartLoop(music,resource);
        if(paused || unfocused)music.Pause();
    }
    public void QuietStage(bool quiet) { stageQuiet=quiet; }
    float duckUntil;
    readonly float[] meterSamples = new float[128];
    float nextMeterSample, meterTarget, meterReading;

    public float ReadProgrammeLevel(float dt)
    {
        if (Time.unscaledTime >= nextMeterSample) {
            nextMeterSample = Time.unscaledTime + .05f;
            music.GetOutputData(meterSamples, 0);
            float sum = 0;
            foreach (float sample in meterSamples) sum += sample * sample;
            float decibels = 10f * Mathf.Log10(Mathf.Max(1e-8f, sum / meterSamples.Length));
            meterTarget = Mathf.InverseLerp(-58f, -17f, decibels);
        }
        meterReading = Mathf.MoveTowards(meterReading, meterTarget, dt * (meterTarget > meterReading ? 5f : 2f));
        return meterReading;
    }

    void Awake()
    {
        music = MakeSource("Cabaret waltz", 120);
        room = MakeSource("Room tone", 180);
        stageVoice=MakeSource("金星の舞台中継",45);
        stageVoice.clip=Resources.Load<AudioClip>("KinseiAudio/stage-testimony");
        for(int i=0;i<floorSpeakers.Length;i++){
            var voice=MakeSource(i==0?"紺谷":"浦",48);
            voice.clip=Resources.Load<AudioClip>("KinseiAudio/"+(i==0?"kontani-yield":"ura-yield"));
            voice.spatialBlend=.44f;voice.minDistance=5;voice.maxDistance=30;voice.dopplerLevel=0;
            floorSpeakers[i]=voice;
        }
        for (int i=0; i<voices.Length; i++) voices[i] = MakeSource("Cue " + i, 100);
        foreach (string key in new[]{"door","dial","shot","distant","strike","choice","result","accord","loss","step"})
        {
            int count = key=="shot" || key=="distant" || key=="strike" || key=="step" ? 3 : 1;
            var set = new AudioClip[count];
            for (int i=0; i<count; i++) set[i]=Resources.Load<AudioClip>("KinseiAudio/"+key+(count>1?i.ToString():""));
            clips[key]=set; variant[key]=0;
        }
        StartLoop(music,"kinsei-waltz"); StartLoop(room,"room");
        ApplyLevels();
    }

    AudioSource MakeSource(string label, int priority)
    {
        var child = new GameObject(label); child.transform.SetParent(transform,false);
        var source = child.AddComponent<AudioSource>();
        source.playOnAwake=false; source.volume=0; source.spatialBlend=0; source.priority=priority;
        return source;
    }
    void StartLoop(AudioSource source,string resource)
    {
        source.clip=Resources.Load<AudioClip>("KinseiAudio/"+resource);
        source.loop=true; if(source.clip!=null) source.Play();
    }
    void Update() { ApplyLevels(); }
    void ApplyLevels()
    {
        if(music==null)return;
        float duck=dialogue ? .38f : Time.unscaledTime<duckUntil ? .48f : 1f;
        float level=stageQuiet?0:Mathf.Clamp01(MusicGain)*.38f*duck;
        music.volume=Mathf.MoveTowards(music.volume,level,Time.unscaledDeltaTime*.7f);
        room.volume=Mathf.Clamp01(AmbientGain)*.16f;
        stageVoice.volume=Mathf.Clamp01(SfxGain)*.92f;
        foreach(var voice in floorSpeakers)voice.volume=Mathf.Clamp01(SfxGain)*.94f;
    }
    // Optional dialogue integration; subtitles remain intelligible without requiring a spoken voice.
    public void SetDialogue(bool active) { dialogue=active; }
    public void Cue(string key)
    {
        if(paused || unfocused || !clips.TryGetValue(key,out var set)) return;
        float now=Time.unscaledTime;
        float spacing=key=="step"?.22f:key=="shot"?.085f:key=="distant"?.19f:key=="strike"?.14f:.16f;
        if(lastCue.TryGetValue(key,out float previous) && now-previous<spacing)return;
        AudioSource source=null;
        foreach(var voice in voices) if(!voice.isPlaying){source=voice;break;}
        // Drop excess bursts rather than multiply loudness or interrupt important cues.
        if(source==null)return;
        int index=variant[key]++%set.Length;
        if(set[index]==null)return;
        lastCue[key]=now; source.clip=set[index];
        bool soft=key=="step"||key=="distant";
        source.volume=Mathf.Clamp01(SfxGain)*(key=="step"?.13f:key=="distant"?.28f:key=="shot"?.63f:.48f);
        source.pitch=soft || key=="shot" || key=="strike" ? 1f+((variant[key]%3)-1)*.025f:1f;
        source.panStereo=key=="distant" ? (index-1)*.24f : 0;
        source.Play();
        if(!soft)duckUntil=now+(key=="accord"||key=="choice"||key=="result"||key=="loss"?2.2f:.7f);
    }
    public void PlayStageTestimony()
    {
        if(!stageVoice.clip)return;
        stageVoice.Play();
        if(paused || unfocused)stageVoice.Pause();
    }
    public void StopStageTestimony() { if(stageVoice)stageVoice.Stop(); }
    public void PlayFloorYield(int person,Vector3 position)
    {
        if(person<0 || person>=floorSpeakers.Length)return;
        var voice=floorSpeakers[person];
        if(!voice.clip)return;
        voice.transform.position=position+Vector3.up*1.18f;
        voice.Play();
        if(paused || unfocused)voice.Pause();
        duckUntil=Mathf.Max(duckUntil,Time.unscaledTime+voice.clip.length);
    }
    public void StopFloorYields(){foreach(var voice in floorSpeakers)if(voice)voice.Stop();}
    public void SetPaused(bool value) { paused=value; ApplyPause(); }
    void OnApplicationFocus(bool focus) { unfocused=!focus; ApplyPause(); }
    void ApplyPause()
    {
        if(music==null)return;
        PauseSource(music); PauseSource(room); PauseSource(stageVoice);
        foreach(var voice in floorSpeakers)PauseSource(voice);
        foreach(var voice in voices)PauseSource(voice);
    }
    void PauseSource(AudioSource source)
    {
        if(paused||unfocused)source.Pause(); else source.UnPause();
    }
    void OnDestroy()
    {
        // Sources are children and destroyed with this component's owner/session.
        if(music!=null)Destroy(music.gameObject);
        if(room!=null)Destroy(room.gameObject);
        if(stageVoice!=null)Destroy(stageVoice.gameObject);
        foreach(var voice in floorSpeakers)if(voice)Destroy(voice.gameObject);
        foreach(var voice in voices)if(voice!=null)Destroy(voice.gameObject);
    }
}
