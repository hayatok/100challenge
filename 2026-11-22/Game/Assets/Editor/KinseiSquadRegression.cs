using System;
using System.Collections;
using System.IO;
using System.Reflection;
using UnityEditor;
using UnityEngine;

[InitializeOnLoad]
public static class KinseiSquadRegression
{
    const string Pending="KinseiSquadRegression.pending";
    const BindingFlags Access=BindingFlags.Instance|BindingFlags.NonPublic|BindingFlags.Public;
    static KinseiSession game;

    static KinseiSquadRegression()
    {
        if(SessionState.GetBool(Pending,false))EditorApplication.update+=WhenReady;
    }

    public static void Run()
    {
        Environment.SetEnvironmentVariable("KINSEI_SAVE_DIRECTORY",
            Path.Combine(Path.GetTempPath(),"KinseiSquads-"+Guid.NewGuid().ToString("N")));
        SessionState.SetBool(Pending,true);
        EditorApplication.update-=WhenReady;
        EditorApplication.update+=WhenReady;
        EditorApplication.EnterPlaymode();
    }

    static object Read(object target,string name)=>target.GetType().GetField(name,Access).GetValue(target);
    static void Write(object target,string name,object value)=>target.GetType().GetField(name,Access).SetValue(target,value);
    static object Call(string name,params object[] args)=>typeof(KinseiSession).GetMethod(name,Access).Invoke(game,args);
    static object Member(int i)=>((IList)Read(game,"crew"))[i];
    static string Duty(int i)=>Read(Member(i),"duty").ToString();
    static Vector3 Destination(int i)=>(Vector3)Read(Member(i),"destination");
    static Vector3 Position(int i)=>((Transform)Read(Member(i),"root")).position;
    static void Select(int i,bool shift=false)=>Call("SelectMember",i,shift);
    static int Selection=>(int)typeof(KinseiSession).GetProperty("SelectedMembers",Access).GetValue(game);
    static void Order(string name,Vector3 point=default)=>Call("Assign",Enum.Parse(Read(Member(0),"duty").GetType(),name),point);
    static void Require(bool value,string failure){if(!value)throw new InvalidOperationException(failure);}

    static void WhenReady()
    {
        if(!EditorApplication.isPlaying)return;
        game=UnityEngine.Object.FindFirstObjectByType<KinseiSession>();
        if(!game || !((KinseiWalkways)Read(game,"walkways")).Ready)return;
        EditorApplication.update-=WhenReady;
        SessionState.EraseBool(Pending);
        try {
            ExerciseOrders();
            Debug.Log("KINSEI_SQUADS_PASS selection / two destinations / single-person jobs / casualties / retry");
            EditorApplication.Exit(0);
        } catch(Exception ex){Debug.LogException(ex);EditorApplication.Exit(1);}
    }

    static void ExerciseOrders()
    {
        Call("StartNight");
        Call("ToggleCommand");
        Select(0);Select(1,true);Select(2,true);Select(2,true);
        Require(Selection==3,"Shift must add and remove seats independently");
        Call("SaveSquad",0);
        Select(3);Select(4,true);Call("SaveSquad",1);
        Call("RecallSquad",0);
        Order("Go",new Vector3(-4,0,-11.6f));
        var first=Destination(0);
        Require(Duty(0)=="Go" && Duty(1)=="Go" && Vector3.Distance(first,Destination(1))>.85f,"First squad shares a destination");
        Call("RecallSquad",1);
        Order("Go",new Vector3(4,0,-11.6f));
        var third=Destination(3);
        Require(Duty(3)=="Go" && Duty(4)=="Go" && Vector3.Distance(first,third)>6,"Second squad overwrote the first order");
        for(int step=0;step<600;step++){
            Write(game,"clock",(float)Read(game,"clock")+1f/60);
            Call("Simulate",1f/60);
        }
        foreach(int i in new[]{0,1,3,4})Require(Vector3.Distance(Position(i),Destination(i))<.5f,"Crew did not reach its assigned place: "+i);
        Require(Vector3.Distance(Position(0),Position(1))>.5f,"Crew overlapped at rest");
        foreach(string work in new[]{"Attend","StageWitness","Backstage","BoxOffice"}){
            Order(work);
            Require(Duty(3)=="Go" && Duty(4)=="Go","Single-person job dispatched to a group: "+work);
        }
        Write(game,"finale",true);Order("Attend");Write(game,"finale",false);
        Require(Read(game,"operatorOnDuty")==null,"Final night accepted a group operator");
        Call("TogglePause");Call("TogglePause");Call("ToggleCommand");Call("ToggleCommand");
        Require(Selection==24,"Pause or camera switch lost the squad");
        Order("Guard");Require(Duty(3)=="Guard" && Duty(4)=="Guard","Guard group order");
        Order("Rest");Require(Duty(3)=="Rest" && Duty(4)=="Rest","Rest group order");
        Order("Follow");Require(Duty(3)=="Follow" && Duty(4)=="Follow","Follow group order");
        Write(Member(3),"hp",0f);
        Call("RecallSquad",1);Require(Selection==16,"Recall selected a casualty");
        Select(4,true);Require(Selection==0,"Could not clear last seat");
        Order("Rest");Require(Duty(4)=="Follow","Empty selection acted");
        Select(1);Order("BoxOffice");Select(2);Order("BoxOffice");
        Require(Duty(1)=="Follow" && Duty(2)=="BoxOffice","More than one ledger runner");
        Write(Member(3),"hp",100f);Call("RecallSquad",1);
        Order("Go",new Vector3(4,0,-11.6f));
        var a=Destination(3);var b=Destination(4);
        Write(Member(0),"hp",0f);Write(Member(1),"hp",0f);
        Call("RecallSquad",0);Order("Go",new Vector3(-4,0,-11.6f));
        Require(Selection==0 && Destination(3)==a && Destination(4)==b,
            "Recalling a squad with no survivors sent the other squad to the new destination");
        Call("StartNight");
        Require(Selection==1 && ((int[])Read(game,"squads"))[0]==0 && ((int[])Read(game,"squads"))[1]==0,"New night kept previous groups");
    }
}
