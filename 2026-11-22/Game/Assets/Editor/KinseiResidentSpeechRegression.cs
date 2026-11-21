using System;
using System.IO;
using System.Reflection;
using UnityEditor;
using UnityEngine;

[InitializeOnLoad]
public static class KinseiResidentSpeechRegression
{
    const string Pending="KinseiResidentSpeechRegression.pending";
    const BindingFlags Access=BindingFlags.Instance|BindingFlags.Public|BindingFlags.NonPublic;
    static KinseiResidentSpeechRegression(){if(SessionState.GetBool(Pending,false))EditorApplication.update+=Check;}
    public static void Run()
    {
        Environment.SetEnvironmentVariable("KINSEI_SAVE_DIRECTORY",Path.Combine(Path.GetTempPath(),"KinseiFaces-"+Guid.NewGuid().ToString("N")));
        SessionState.SetBool(Pending,true);EditorApplication.update-=Check;EditorApplication.update+=Check;EditorApplication.EnterPlaymode();
    }
    static object Read(object target,string name)=>target.GetType().GetField(name,Access).GetValue(target);
    static object Call(KinseiSession game,string name,params object[] args)=>typeof(KinseiSession).GetMethod(name,Access).Invoke(game,args);
    static void Assert(bool value,string why){if(!value)throw new InvalidOperationException(why);}
    static void Check()
    {
        var game=UnityEngine.Object.FindFirstObjectByType<KinseiSession>();
        if(!EditorApplication.isPlaying || !game || !((KinseiWalkways)Read(game,"walkways")).Ready)return;
        EditorApplication.update-=Check;SessionState.EraseBool(Pending);
        try{
            Call(game,"StartNight");
            var people=(KinseiDistrictPeople)Read(game,"neighbours");
            var player=(Transform)Read(Read(game,"player"),"root");
            // Sakita is already at the central customer seat when the night starts.
            player.position=new Vector3(-16.79f,.065f,-17.39f);Physics.SyncTransforms();
            string guestVerb=(string)Call(game,"Interaction");
            Assert(guestVerb.Contains("崎田"),"Expected the customer nearest the central seat: "+guestVerb);
            Call(game,"Interact");
            Assert(!people.SpeakingOwner,"A customer's line animated a shopkeeper");
            var portrait=typeof(KinseiSession).GetField("portraitOwner",Access);
            portrait.SetValue(game,people.Owner(0));
            Assert(((string)Call(game,"Interaction")).Contains("澄子"),"Focused conversation switched to a bystander");
            Call(game,"Interact");
            Assert(people.SpeakingOwner==people.Owner(0),"Answer came from outside the portrait");
            portrait.SetValue(game,null);
            people.ResetNight();
            for(int shop=0;shop<3;shop++){
                var actor=people.Owner(shop);
                var other=people.Owner((shop+1)%3);
                var skin=(SkinnedMeshRenderer)Read(actor,"faceRenderer");
                var otherSkin=(SkinnedMeshRenderer)Read(other,"faceRenderer");
                int open=skin.sharedMesh.GetBlendShapeIndex("Conversational lip opening");
                int otherOpen=otherSkin.sharedMesh.GetBlendShapeIndex("Conversational lip opening");
                Assert(open>=0 && otherOpen>=0,"Imported mesh has no opening shape");
                // Stand in the walkable left-hand aisle, clear of the worktop and waiting customers.
                player.position=new Vector3((shop-1)*16f-2.76f,.065f,-18.70f);
                Physics.SyncTransforms();
                string verb=(string)Call(game,"Interaction");
                Call(game,"Interact");
                Assert(people.SpeakingOwner==actor,"Wrong speaker at shop "+shop+" "+player.position+
                    ", action "+verb+", displayed line "+Read(game,"banner"));
                var eyes=actor.EyePosition+actor.transform.forward*1.55f+actor.transform.right*.38f;
                float maximum=0,blink=0;
                for(int i=0;i<90;i++){
                    float t=i/60f;people.Tick(t);people.LookAtNeighbours();people.PoseCounterLine(t,eyes);
                    maximum=Mathf.Max(maximum,skin.GetBlendShapeWeight(open));blink=Mathf.Max(blink,skin.GetBlendShapeWeight(0));
                    Assert(otherSkin.GetBlendShapeWeight(otherOpen)==0,"Another owner moved their lips");
                }
                Assert(maximum>35 && blink>80,"Speech did not open the mouth and close the lids");
                people.Tick(7f);people.PoseCounterLine(7f,eyes);
                Assert(!people.SpeakingOwner && skin.GetBlendShapeWeight(open)==0,"Expression remained after dialogue");
                people.ResetNight();
            }
            Debug.Log("KINSEI_RESIDENT_SPEECH_PASS all three shop contacts / exclusive speaker / lid closure / release");EditorApplication.Exit(0);
        }catch(Exception ex){Debug.LogException(ex);EditorApplication.Exit(1);}
    }
}
