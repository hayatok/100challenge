using UnityEngine;

public sealed partial class KinseiDistrictPeople
{
    KinseiActor speaker;
    string counterLine="";
    float speakingAt,lineDuration,releaseAt=float.PositiveInfinity;

    public KinseiActor SpeakingOwner => speaker;
    public KinseiActor Owner(int shop)=>shop>=0 && shop<3?locals[shop].actor:null;

    public void BeginCounterLine(int shop,string words,float now,float seconds,Vector3 listener)
    {
        var actor=Owner(shop);
        if(!actor || (actor.EyePosition-listener).sqrMagnitude>10.9f)return;
        int start=words.IndexOf('「'),end=words.LastIndexOf('」');
        if(start<0 || end<=start+1)return;
        ClearCounterLine();
        speaker=actor;counterLine=words.Substring(start+1,end-start-1);
        speakingAt=now;lineDuration=Mathf.Min(seconds-.26f,Mathf.Clamp(.36f+counterLine.Length*.112f,.72f,4.15f));
        releaseAt=now+lineDuration;
    }

    public void EndCounterLine(float now){if(speaker)releaseAt=Mathf.Min(releaseAt,now);}
    void ClearCounterLine()
    {
        if(speaker)speaker.ReleaseCounterLine();
        speaker=null;counterLine="";releaseAt=float.PositiveInfinity;
    }

    public void PoseCounterLine(float now,Vector3 listener)
    {
        if(!speaker)return;
        if((listener-speaker.EyePosition).sqrMagnitude>12.25f)EndCounterLine(now);
        float t=now-speakingAt;
        float release=Mathf.SmoothStep(1,0,Mathf.Clamp01((now-releaseAt)/.24f));
        if(t<0 || release<=0){ClearCounterLine();return;}
        float gaze=Mathf.SmoothStep(0,1,Mathf.Clamp01(t/.20f))*release;
        float phase=Mathf.Clamp01((t-.12f)/Mathf.Max(.2f,lineDuration-.22f))*counterLine.Length;
        int index=Mathf.Min(counterLine.Length-1,(int)phase);
        char c=counterLine[index];
        float pulse=Mathf.Sin(Mathf.PI*(phase-Mathf.Floor(phase)));
        bool closed="っッんン、。！？…　 ".IndexOf(c)>=0;
        float vowel="あかさたなはまやらわアカサタナハマヤラワ".IndexOf(c)>=0?.95f:
            "いきしちにひみりイキシチニヒミリ".IndexOf(c)>=0?.40f:.59f+(index%3)*.09f;
        bool round="うくすつぬふむゆるおこそとのほもよろをウクスツヌフムユルオコソトノホモヨロ".IndexOf(c)>=0;
        float strength=closed || t<.12f || t>=lineDuration-.10f?0:gaze*(.12f+.88f*pulse);
        float blink=Mathf.SmoothStep(0,1,Mathf.Clamp01((t-.19f)/.045f))*
            (1-Mathf.SmoothStep(0,1,Mathf.Clamp01((t-.251f)/.092f)))*release;
        speaker.PerformCounterLine(listener,gaze,strength*vowel,round?strength:0,blink);
    }
}
