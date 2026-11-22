using System;
using System.Collections;
using System.IO;
using System.Reflection;
using UnityEditor;
using UnityEngine;

[InitializeOnLoad]
public static class KinseiPressViewRegression
{
    const string Pending="KinseiPressViewRegression.pending";
    const BindingFlags Access=BindingFlags.Public|BindingFlags.NonPublic|BindingFlags.Instance;
    static KinseiPressViewRegression(){if(SessionState.GetBool(Pending,false))EditorApplication.update+=Ready;}

    public static void Run()
    {
        Environment.SetEnvironmentVariable("KINSEI_SAVE_DIRECTORY",Path.Combine(Path.GetTempPath(),"KinseiPress-"+Guid.NewGuid().ToString("N")));
        SessionState.SetBool(Pending,true);
        EditorApplication.update-=Ready;EditorApplication.update+=Ready;EditorApplication.EnterPlaymode();
    }

    static object Get(object owner,string name)=>owner.GetType().GetField(name,Access).GetValue(owner);
    static void Set(object owner,string name,object value)=>owner.GetType().GetField(name,Access).SetValue(owner,value);
    static void Call(object owner,string name,params object[] args)=>owner.GetType().GetMethod(name,Access).Invoke(owner,args);
    static Transform Root(object person)=>(Transform)Get(person,"root");

    static void Ready()
    {
        if(!EditorApplication.isPlaying)return;
        var game=UnityEngine.Object.FindFirstObjectByType<KinseiSession>();
        if(!game || !(Get(game,"walkways") is KinseiWalkways routes) || !routes.Ready)return;
        SessionState.EraseBool(Pending);EditorApplication.update-=Ready;
        try{
            var store=(KinseiLedgerStore)Get(game,"ledgerStore");
            foreach(var ending in new[]{"accord","pursuit"})store.Change(l=>{l.nights++;l.Settle(ending,0);});
            foreach(var start in new[]{new Vector3(-3.44f,.03f,-2.90f),new Vector3(-4.93f,.03f,-2.93f),new Vector3(-1.48f,.03f,-6.32f)})
                CheckOpening(game,start);
            Debug.Log("KINSEI_PRESS_VIEW_PASS both recorded positions and front-of-press player, crew clearance and exclusive settlement");
            EditorApplication.Exit(0);
        }catch(Exception error){Debug.LogException(error);EditorApplication.Exit(1);}
    }

    static void CheckOpening(KinseiSession game,Vector3 start)
    {
        Call(game,"OpenNight",true);
        var player=Root(Get(game,"player"));player.position=KinseiBoxOffice.Counter;
        var step=game.GetType().GetField("finaleStep",Access);
        step.SetValue(game,Enum.Parse(step.FieldType,"Choose"));Call(game,"FinaleInteract");
        player.position=start;
        var crew=(IList)Get(game,"crew");
        for(int i=0;i<crew.Count;i++)
            Root(crew[i]).position=start+new Vector3(i%2==0?-1.75f:1.75f,0,-1.7f-(i/2)*1.05f);
        Physics.SyncTransforms();
        Set(game,"chosen",2);Call(game,"OrderFinale");
        float worst=10,playerClearance=10,clock=(float)Get(game,"clock"),onAir=-1;
        for(int frame=0;frame<1200;frame++){
            clock+=1f/60;Set(game,"clock",clock);Call(game,"SimulateFinale",1f/60);
            onAir=(float)Get(game,"firstPictureAt");
            if(Get(game,"phase").ToString()=="Result")break;
            if(onAir<0)continue;
            float t=Mathf.SmoothStep(0,1,Mathf.InverseLerp(1.63f,2.68f,clock-onAir));
            // Use the selected gameplay lens and aim; horizontal clearance is conservative for upright bodies.
            Call(game,"SetCamera",1f/60);
            var cam=(Camera)Get(game,"cam");
            Vector3 eye=cam.transform.position,point=KinseiBoxOffice.Counter+
                Vector3.Lerp(new Vector3(.40f,1.12f,.49f),new Vector3(.38f,1.09f,.425f),t);
            Vector3 paper=eye+Vector3.Project(point-eye,cam.transform.forward);
            eye.y=paper.y=0;
            var ray=paper-eye;
            var viewer=player.position;viewer.y=0;
            float along=Mathf.Clamp01(Vector3.Dot(viewer-eye,ray)/ray.sqrMagnitude);
            playerClearance=Mathf.Min(playerClearance,Vector3.Distance(viewer,eye+along*ray));
            foreach(object member in crew){
                Vector3 at=Root(member).position;at.y=0;
                float u=Mathf.Clamp01(Vector3.Dot(at-eye,ray)/ray.sqrMagnitude);
                worst=Mathf.Min(worst,Vector3.Distance(at,eye+u*ray));
            }

        }
        if(worst<.65f || playerClearance<.36f || onAir<0 || (string)Get(game,"outcome")!="exclusive" || Mathf.Abs(clock-onAir-3.6f)>.035f || player.position!=start)
            throw new InvalidOperationException("Opening failed at "+start+"; projected clearance "+worst+"m, player "+playerClearance+"m, picture age "+(clock-onAir));
        Debug.Log("KINSEI_PRESS_VIEW start="+start+" min crew-to-shot distance "+worst+"m, player "+playerClearance+"m");
    }
}
