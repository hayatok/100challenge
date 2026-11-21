using System;
using System.Collections;
using System.IO;
using System.Reflection;
using UnityEditor;
using UnityEngine;

[InitializeOnLoad]
public static class KinseiShowdownRegression
{
    const string Pending = "KinseiShowdownRegression.pending";
    const BindingFlags Fields = BindingFlags.Instance | BindingFlags.Static | BindingFlags.NonPublic | BindingFlags.Public;
    const float Dt = 1f / 60f;
    static KinseiSession session;

    static KinseiShowdownRegression()
    {
        if (SessionState.GetBool(Pending, false)) EditorApplication.update += WhenPlaying;
    }

    public static void Run()
    {
        string directory = Path.Combine(Path.GetTempPath(), "KinseiShowdownRegression-" + Guid.NewGuid().ToString("N"));
        Environment.SetEnvironmentVariable("KINSEI_SAVE_DIRECTORY", directory);
        SessionState.SetBool(Pending, true);
        EditorApplication.update -= WhenPlaying;
        EditorApplication.update += WhenPlaying;
        EditorApplication.EnterPlaymode();
    }

    static void WhenPlaying()
    {
        if (!EditorApplication.isPlaying) return;
        session = UnityEngine.Object.FindFirstObjectByType<KinseiSession>();
        if (session == null || !Read<KinseiWalkways>(session, "walkways").Ready) return;
        EditorApplication.update -= WhenPlaying;
        SessionState.EraseBool(Pending);
        try
        {
            CheckWitness();
            CheckNormalEndings();
            CheckStageWin();
            CheckStageLoss();
            Debug.Log("KINSEI_SHOWDOWN_PASS witness / pursuit / accord / stage win / stage loss");
            EditorApplication.Exit(0);
        }
        catch (Exception ex)
        {
            Debug.LogException(ex);
            EditorApplication.Exit(1);
        }
    }

    static FieldInfo Field(object target, string name) => target.GetType().GetField(name, Fields);
    static T Read<T>(object target, string name) => (T)Field(target, name).GetValue(target);
    static void Set(object target, string name, object value) => Field(target, name).SetValue(target, value);
    static object Call(string name, params object[] args) => typeof(KinseiSession).GetMethod(name, Fields).Invoke(session, args);
    static object Player => Read<object>(session, "player");
    static object Boss => Read<object>(session, "boss");
    static object Crew(int index) => Read<IList>(session, "crew")[index];
    static Vector3 Steps => Read<Vector3>(session, "StageSteps");
    static Vector3 Wing => Read<Vector3>(session, "StageWing");
    static Transform Root(object person) => Read<Transform>(person, "root");
    static float Hp(object person) => Read<float>(person, "hp");
    static string Phase => Read<object>(session, "phase").ToString();
    static string Beat => Read<object>(session, "stageBeat").ToString();
    static string Verb => (string)Call("Interaction");

    static void Require(bool condition, string message)
    {
        if (!condition) throw new InvalidOperationException(message + " (phase " + Phase + ", beat " + Beat + ")");
    }

    static void Step()
    {
        Set(session, "clock", Read<float>(session, "clock") + Dt);
        Set(session, "phaseAge", Read<float>(session, "phaseAge") + Dt);
        Call("Simulate", Dt);
    }

    static void Await(Func<bool> ready, int seconds, string message)
    {
        for (int i = 0; i < 60 * seconds && !ready(); i++) Step();
        Require(ready(), message);
    }

    static void Order(int index, string name)
    {
        Set(session, "chosen", index);
        Call("Assign", Enum.Parse(Field(Crew(index), "duty").FieldType, name), Vector3.zero);
    }

    static object Witness => Read<object>(session, "stageWitness");

    static void CheckWitness()
    {
        Call("StartNight");
        Call("ToggleCommand");
        Order(1, "StageWitness");
        Require(Phase == "Arrival" && Witness == Crew(1), "Street assignment failed");
        Order(2, "StageWitness");
        Require(Witness == Crew(2) && Read<object>(Crew(1), "duty").ToString() == "Follow", "Replacement left the old witness at their post");
        Order(2, "Attend");
        Require(Witness == Crew(2), "Rejected reassignment removed witness");
        Call("ToggleCommand");
        Await(() => (bool)typeof(KinseiSession).GetProperty("StageWitnessReady", Fields).GetValue(session), 12, "Witness did not reach the wing by walking");
        Root(Player).position = Steps + Vector3.up * 3.2f;
        Require(Verb.Length == 0, "Upstairs mistakenly offers the challenge");
        Root(Player).position = Steps;
        Require(Verb == "舞台の勝負を受ける", "Waiting witness did not unlock the prompt");
        Set(Crew(2), "hp", 0f);
        Call("Interact");
        Require(Phase == "Arrival", "Incapacitated witness started the showdown");
        Step();
        Require(Witness == null && Phase == "Floor", "Witness invalidation blocked the ordinary floor");
        Order(1, "StageWitness");
        Order(1, "Guard");
        Require(Witness == null && Read<object>(Crew(1), "duty").ToString() == "Guard", "New valid duty failed to release the witness");
        Debug.Log("KINSEI_SHOWDOWN witness path, replacement, rejected and accepted reassignment, incapacitation");
    }

    static void HallCleared()
    {
        Call("StartNight");
        Root(Player).position = new Vector3(0, 0, -3.1f);
        Step();
        Set(Read<object>(session, "brother"), "hp", 0f);
        foreach (object guard in Read<IList>(session, "guards")) Set(guard, "hp", 0f);
        Step();
        Require(Phase == "Choice", "Ordinary fight no longer reaches Choice");
    }

    static void CheckNormalEndings()
    {
        HallCleared();
        Root(Crew(1)).position = Wing;
        Order(1, "StageWitness");
        Order(1, "StageWitness");
        Require(Witness == null, "Same-person V did not cancel the appointment");
        Root(Player).position = Root(Boss).position + Vector3.left;
        Require(Verb == "兄貴分を追う", "Pursuit unavailable after cancellation");
        Call("Interact");
        Require(Phase == "Chase", "Pursuit interaction no longer transitions");
        Set(Boss, "hp", 0f);
        Step();
        Require(Read<string>(session, "outcome") == "pursuit", "Ordinary pursuit no longer settles");

        HallCleared();
        Root(Crew(1)).position = Wing;
        Order(1, "StageWitness");
        object brother = Read<object>(session, "brother");
        Root(Player).position = Root(brother).position;
        Require(Verb == "弟に肩を貸す", "Ready witness displaced the escort interaction");
        Call("Interact");
        Require(Read<bool>(session, "escorted"), "Escort unavailable with an unused witness");
        Root(Crew(0)).position = Read<Vector3>(session, "table");
        Order(0, "Attend");
        Await(() => Read<bool>(session, "held"), 2, "Tatsu could not negotiate beside the witness order");
        Root(Player).position = Read<Vector3>(session, "witness");
        Call("Interact");
        Await(() => Phase == "Release", 6, "Escort could not reach the mirror and release");
        Root(Read<object>(session, "elder")).position = new Vector3(-.45f, 0, -11f);
        Root(brother).position = new Vector3(.2f, 0, -10.84f);
        Step();
        Require(Read<string>(session, "outcome") == "accord", "Ordinary accord no longer settles");
        Debug.Log("KINSEI_SHOWDOWN pursuit after V cancellation / accord with unused witness");
    }

    static void DeclareStage()
    {
        Call("StartNight");
        Root(Player).position = Steps;
        Step();
        Root(Crew(2)).position = Wing;
        Order(2, "StageWitness");
        object guard = Read<IList>(session, "guards")[0];
        Set(guard, "watching", Player);
        Call("Interact");
        Require(Phase == "Showdown", "Stage E failed in the hall");
        Require(Read<object>(guard, "watching") == null, "A queued gunshot survived the declaration");
        Call("ToggleCommand");
        Require(!Read<bool>(session, "command"), "The duel unexpectedly switched to orders");
    }

    static void CheckStageWin()
    {
        DeclareStage();
        Set(session, "reducedMotion", true);
        float playerHp = Hp(Player);
        Root(Boss).position = new Vector3(-8.9f, -1f, 5f);
        Step();
        Require(Mathf.Abs(Root(Boss).position.y - .48f) < .005f && Root(Boss).position.z <= 4.11f,
            "Boss recovery left a combatant outside the boards");
        for (int i = 0; i < 3; i++)
        {
            Await(() => Beat == "Cue", 6, "No warning");
            Require(Read<LineRenderer>(session, "stageRing").enabled, "Reduced motion hid the warning ring");
            float bossHp = Hp(Boss);
            Call("Attack", false, false);
            Call("Attack", true, false);
            Require(Hp(Boss) == bossHp, "Weapon or early F broke the scripted opening");
            Vector3 mark = Read<Vector3>(session, "stageMark");
            Root(Player).position = mark + Vector3.right * (mark.x < -5f ? 1.05f : -1.05f);
            Await(() => Beat == "Opening", 3, "No opening after the swing");
            var ring = Read<LineRenderer>(session, "stageRing");
            Require(ring.enabled && ring.startColor.g > .88f && ring.startColor.b > .7f,
                "The opening must show the white floor ring even with reduced motion");
            Require(Hp(Player) == playerHp, "Standing outside the marked area caused damage");
            var opponent = Root(Boss).position;
            Root(Player).position = opponent + Vector3.right * (opponent.x < -5f ? .98f : -.98f);
            Call("Attack", true, false);
            Require(Hp(Boss) == Mathf.Max(0, bossHp - 34), "F at the opening did not count");
            Require(!ring.enabled, "The white ring still invites another hit after the counter");
            if (i == 2) break;
            for (int frame = 0; frame < 27; frame++) Step();
            Call("Attack", true, false);
            Require(Hp(Boss) == bossHp - 34, "One opening counted twice");
        }
        Await(() => Phase == "Result", 2, "Stage victory did not reach an ending");
        Require(Read<string>(session, "outcome") == "showdown" && Read<KinseiLedger>(session, "ledger").stagePromise,
            "Stage victory did not get its own outcome and the existing promise");
        Debug.Log("KINSEI_SHOWDOWN clamped floor / warning and dodge / three openings / stage promise");
    }

    static void CheckStageLoss()
    {
        DeclareStage();
        int returned = Read<KinseiLedger>(session, "ledger").completed;
        Call("ClaimHouse");
        Set(Player, "hp", 8f);
        Await(() => Beat == "Opening", 8, "No stationary hit");
        Require(Vector3.Distance(Root(Player).position, Root(Boss).position) >= .919f,
            "The two torsos overlap after a stationary hit");
        Await(() => Phase == "Result", 9, "Stationary player never lost after the warning");
        Require(Hp(Player) == 0 && Read<string>(session, "outcome") == "loss" &&
            Read<int>(session, "receipts") == 0 && Read<KinseiLedger>(session, "ledger").completed == returned,
            "Stage defeat booked the wrong ledger outcome");
        Debug.Log("KINSEI_SHOWDOWN stationary defeat / lost receipts");
    }
}
