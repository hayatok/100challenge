using System;
using System.Collections;
using System.Reflection;
using UnityEditor;
using UnityEngine;

[InitializeOnLoad]
public static class KinseiChoiceRegression
{
    const string Pending = "KinseiChoiceRegression.pending";
    const BindingFlags Fields = BindingFlags.Instance | BindingFlags.NonPublic | BindingFlags.Public;

    static KinseiChoiceRegression()
    {
        if(SessionState.GetBool(Pending, false))
            EditorApplication.update += WhenPlaying;
    }

    static void WhenPlaying()
    {
        if(!EditorApplication.isPlaying || UnityEngine.Object.FindFirstObjectByType<KinseiSession>() == null)
            return;
        EditorApplication.update -= WhenPlaying;
        Check();
    }

    public static void Run()
    {
        SessionState.SetBool(Pending, true);
        EditorApplication.update -= WhenPlaying;
        EditorApplication.update += WhenPlaying;
        EditorApplication.EnterPlaymode();
    }

    static FieldInfo Field(object target, string name) => target.GetType().GetField(name, Fields);
    static object Read(object target, string name) => Field(target,name).GetValue(target);
    static void Set(object target, string name, object value) => Field(target,name).SetValue(target,value);
    static void Call(object target, string name, params object[] args) =>
        target.GetType().GetMethod(name, Fields).Invoke(target,args);

    static void Check()
    {
        SessionState.EraseBool(Pending);
        try {
            var session = UnityEngine.Object.FindFirstObjectByType<KinseiSession>();
            Call(session, "StartNight");
            object tatsu = ((IList)Read(session,"crew"))[0];
            var phase = Field(session,"phase");
            foreach(bool down in new[]{false,true})
            foreach(bool escorted in new[]{false,true})
            foreach(bool held in new[]{false,true})
            foreach(bool escaped in new[]{false,true}) {
                phase.SetValue(session,Enum.Parse(phase.FieldType,"Choice"));
                Set(session,"escorted",escorted);
                Set(session,"held",held);
                Set(session,"talkProgress",held?2f:0f);
                Set(session,"escapeTime",escaped?0f:4f);
                Set(tatsu,"hp",down?0f:100f);
                Call(session,"Simulate",1f/60f);
                bool loss = escaped && (down || (!escorted && !held));
                string expected = loss ? "Result" : "Choice";
                string actual = Read(session,"phase").ToString();
                if(actual!=expected || (loss && (string)Read(session,"outcome")!="loss") ||
                    (down && ((bool)Read(session,"held") || (float)Read(session,"talkProgress")!=0f)))
                    throw new InvalidOperationException($"down={down} escort={escorted} held={held} escape={escaped}: {actual}, expected {expected}");
                Debug.Log($"KINSEI_CHOICE down={down} escort={escorted} held={held} escaped={escaped} -> {actual}");
            }
            Debug.Log("KINSEI_CHOICE_PASS 16/16");
            EditorApplication.Exit(0);
        } catch(Exception ex) {
            Debug.LogException(ex);
            EditorApplication.Exit(1);
        }
    }
}
