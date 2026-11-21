using System;
using UnityEngine;

public sealed partial class KinseiWorld
{
    [Serializable] sealed class ScoreNote { public float beat,beats; public int midi; }
    [Serializable] sealed class ScoreBar { public int[] chord; public ScoreNote[] melody; }
    [Serializable] sealed class WaltzScore { public int bpm; public ScoreBar[] bars; }

    const int FirstKey=36;
    readonly Transform[] keys=new Transform[61];
    readonly Vector3[] keyRest=new Vector3[61];
    readonly float[] keyDepth=new float[61], strike=new float[61];
    static readonly int[] Naturals={0,2,4,5,7,9,11};
    WaltzScore waltz;

    void FitKeyboard(Transform piano)
    {
        var score=Resources.Load<TextAsset>("KinseiAudio/StageScore");
        waltz=JsonUtility.FromJson<WaltzScore>(score.text);
        for(int i=0;i<36;i++) {
            float x=(i-17.5f)*.035f;
            int index=(i/7)*12+Naturals[i%7];
            FitKey(piano,index,new Vector3(x,.765f,-.326f),new Vector3(.033f,.028f,.198f),ivoryKeys);
            if(i%7!=2 && i%7!=6 && i<35)
                FitKey(piano,index+1,new Vector3(x+.0175f,.791f,-.286f),new Vector3(.020f,.040f,.116f),dark);
        }
    }

    void FitKey(Transform piano,int index,Vector3 rest,Vector3 shape,Material finish)
    {
        var key=Box("鍵盤 "+(FirstKey+index),rest,shape,finish,false,piano);
        Moving(key);keys[index]=key.transform;keyRest[index]=rest;
    }

    void StrikeKey(int midi,float age,float hold)
    {
        if(age<0 || age>hold+.075f)return;
        float depth=Mathf.Clamp01(age/.022f)*(1-Mathf.InverseLerp(hold,hold+.075f,age));
        int index=midi-FirstKey;
        strike[index]=Mathf.Max(strike[index],depth);
    }

    public void PlayKeys(float seconds,bool playing,out Vector3 left,out Vector3 right)
    {
        Array.Clear(strike,0,strike.Length);
        float quarter=60f/waltz.bpm;
        float beat=Mathf.Repeat(seconds/quarter,waltz.bars.Length*3);
        int barIndex=Mathf.FloorToInt(beat/3);
        float localBeat=beat-barIndex*3;
        var bar=waltz.bars[barIndex];
        int melody=bar.melody[0].midi;
        for(int i=0;i<bar.melody.Length;i++) {
            var pitch=bar.melody[i];
            if(localBeat>=pitch.beat-.15f)melody=pitch.midi;
            if(playing)StrikeKey(pitch.midi,(localBeat-pitch.beat)*quarter,Mathf.Min(.56f,pitch.beats*quarter*.84f));
        }
        if(playing)for(int pulse=1;pulse<=2;pulse++)for(int i=0;i<bar.chord.Length;i++)
            StrikeKey(bar.chord[i],(localBeat-pulse)*quarter-i*.012f,.26f);
        for(int i=0;i<keys.Length;i++) {
            if(Mathf.Abs(strike[i]-keyDepth[i])<.0001f)continue;
            keys[i].localPosition=keyRest[i]-Vector3.up*strike[i]*.008f;
            keys[i].localRotation=Quaternion.Euler(-2.5f*strike[i],0,0);keyDepth[i]=strike[i];
        }
        left=KeySurface(bar.chord[1]);right=KeySurface(melody);
    }

    Vector3 KeySurface(int midi)
    {
        var key=keys[midi-FirstKey];
        return key.TransformPoint(new Vector3(0,.5f,-.22f));
    }
}
