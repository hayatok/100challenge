using System;
using System.IO;
using System.Text;
using UnityEngine;

[Serializable]
public sealed class KinseiLedger
{
    public int version;
    public int nights;
    public int completed;
    public int lastSettledNight;
    public long earnings;
    public bool kajiPromise;
    public bool stagePromise;
    public bool cooperativeEnding;
    public bool exclusiveEnding;
    public string seal;

    public static KinseiLedger Blank()
    {
        return new KinseiLedger { version = 1, seal = "金星・出納帳" };
    }

    public bool IsValid()
    {
        return version == 1 && seal == "金星・出納帳" && nights >= 0 &&
            completed >= 0 && completed <= lastSettledNight && lastSettledNight <= nights &&
            (completed != 0 || lastSettledNight == 0) && earnings >= 0 &&
            earnings <= (long)completed * 18000 &&
            (!(cooperativeEnding || exclusiveEnding) || (kajiPromise && stagePromise && completed >= 3)) &&
            (completed == 0 ? (!kajiPromise && !stagePromise) : (kajiPromise || stagePromise));
    }

    public int CrewShift { get { return nights <= 1 ? 0 : (nights - 1) % 3; } }
    public int Receipts { get { return 12000 + (stagePromise ? 4000 : 0) + (kajiPromise ? 2000 : 0); } }

    public void Settle(string ending, int receipts)
    {
        if (nights <= lastSettledNight) throw new InvalidDataException("今夜の売上は記帳済みです");
        bool final = ending == "cooperative" || ending == "exclusive";
        if (final && (!kajiPromise || !stagePromise || receipts != 0)) throw new InvalidDataException("最終夜の記録が合いません");
        if (!final && ending != "accord" && ending != "pursuit") throw new ArgumentException("不明な決着");
        if (receipts != 0 && receipts != Receipts) throw new ArgumentException("伝票の金額が合いません");
        completed = checked(completed + 1);
        lastSettledNight = nights;
        earnings = checked(earnings + receipts);
        if (ending == "accord") kajiPromise = true;
        else if (ending == "pursuit") stagePromise = true;
        else if (ending == "cooperative") cooperativeEnding = true;
        else exclusiveEnding = true;
    }
}

public sealed class KinseiLedgerStore
{
    readonly string file, backup;
    public bool Recovered { get; private set; }

    public KinseiLedgerStore(string directory)
    {
        file = Path.Combine(directory, "kinsei-ledger.json");
        backup = file + ".bak";
    }

    KinseiLedger Read(string path)
    {
        var data = JsonUtility.FromJson<KinseiLedger>(File.ReadAllText(path, Encoding.UTF8));
        if (data == null || !data.IsValid()) throw new InvalidDataException("帳面の内容を確認できません");
        return data;
    }

    public KinseiLedger Load()
    {
        Recovered = false;
        if (File.Exists(file))
        {
            try { return Read(file); }
            catch (Exception e) when ((e is IOException || e is InvalidDataException || e is ArgumentException) && File.Exists(backup)) { }
        }
        if (!File.Exists(backup)) return KinseiLedger.Blank();
        var restored = Read(backup);
        Recovered = true;
        return restored;
    }

    // A short-lived exclusive lock also serializes two Windows game processes.
    public KinseiLedger Change(Action<KinseiLedger> edit)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(file));
        using (var held = new FileStream(file + ".lock", FileMode.OpenOrCreate, FileAccess.Write, FileShare.None))
        {
            var data = Load();
            bool preserveBackup = Recovered;
            edit(data);
            if (!data.IsValid()) throw new InvalidDataException("帳面の更新内容が不正です");
            string temporary = file + "." + Guid.NewGuid().ToString("N") + ".tmp";
            try
            {
                var bytes = Encoding.UTF8.GetBytes(JsonUtility.ToJson(data, true));
                using (var stream = new FileStream(temporary, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                {
                    stream.Write(bytes, 0, bytes.Length);
                    stream.Flush(true);
                }
                Read(temporary);
                if (File.Exists(file)) File.Replace(temporary, file, preserveBackup ? null : backup);
                else File.Move(temporary, file);
            }
            finally { if (File.Exists(temporary)) File.Delete(temporary); }
            return data;
        }
    }
}


