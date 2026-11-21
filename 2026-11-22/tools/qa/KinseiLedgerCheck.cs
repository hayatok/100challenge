using System;
using System.IO;
using UnityEditor;
using UnityEngine;

public static class KinseiLedgerCheck
{
    static void Check(bool ok, string label)
    {
        if (!ok) throw new Exception(label);
        Debug.Log("KINSEI_CHECK " + label);
    }

    public static void Run()
    {
        string dir = Path.Combine(Path.GetTempPath(), "kinsei-check-" + Guid.NewGuid().ToString("N"));
        var store = new KinseiLedgerStore(dir);
        var clean = store.Load();
        Check(clean.nights == 0 && clean.Receipts == 12000, "fresh");
        var first = store.Change(d => d.nights++);
        Check(first.CrewShift == 0, "initial cast");
        int unpaid = first.Receipts;
        var second = store.Change(d => d.nights++);
        Check(second.earnings == 0 && second.CrewShift == 1 && unpaid > 0, "abandonment and cast rotation");
        store.Change(d => d.Settle("accord", d.Receipts));
        var returned = new KinseiLedgerStore(dir).Load();
        Check(returned.kajiPromise && !returned.stagePromise && returned.earnings == 12000 && returned.Receipts == 14000, "accord persisted");
        bool duplicate = false;
        try { store.Change(d => d.Settle("accord", d.Receipts)); } catch (InvalidDataException) { duplicate = true; }
        Check(duplicate && store.Load().earnings == 12000, "duplicate settlement refused");
        var third = store.Change(d => d.nights++);
        Check(third.CrewShift == 2 && third.completed == 1, "third shift");
        store.Change(d => d.Settle("pursuit", d.Receipts));
        var fourth = store.Change(d => d.nights++);
        Check(fourth.CrewShift == 0 && fourth.completed == 2 && fourth.Receipts == 18000 && fourth.earnings == 26000, "pursuit and repeat after victory");
        store.Change(d => d.Settle("pursuit", 0));
        Check(store.Load().earnings == 26000, "optional claim");
        string file = Path.Combine(dir, "kinsei-ledger.json");
        File.WriteAllText(file, "{}");
        Check(store.Load().completed == 2 && store.Recovered, "invalid fields restore backup");
        store.Change(d => d.nights++);
        Check(store.Load().nights == 5, "recovery update");
        File.WriteAllText(file, "{");
        Check(store.Load().completed == 2 && store.Recovered, "malformed JSON restores retained backup");
        File.WriteAllText(file + ".bak", "{}");
        bool rejected = false;
        try { store.Change(d => d.nights++); } catch (InvalidDataException) { rejected = true; }
        Check(rejected && File.ReadAllText(file) == "{", "double corruption preserved");
        Debug.Log("KINSEI_LEDGER_PASS");
    }
}

