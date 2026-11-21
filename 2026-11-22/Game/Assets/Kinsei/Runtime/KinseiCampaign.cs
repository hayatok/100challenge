using System;
using System.IO;
using UnityEngine;

public sealed partial class KinseiSession
{
    KinseiLedgerStore ledgerStore;
    KinseiLedger ledger = KinseiLedger.Blank();
    int receipts;
    string pendingEnding;
    string settlementMessage;
    string CampaignError { get; set; } = "";
    bool HouseClaimed { get { return receipts != 0; } }
    string CampaignSummary
    {
        get
        {
            string ties = ledger.kajiPromise ? "辰と梶の約束" : "";
            if (ledger.stagePromise) ties += (ties.Length > 0 ? "・" : "") + "金星座長の約束";
            if (ties.Length == 0) ties = "まだ約束はない";
            if(ledger.cooperativeEnding || ledger.exclusiveEnding) ties+="\n終幕　"+(ledger.cooperativeEnding?"四十店共同　":"")+(ledger.exclusiveEnding?"金星専属":"");
            return $"出撃 {ledger.nights} 回　帰還 {ledger.completed} 回　累計売上 {ledger.earnings:N0} 円\n{ties}";
        }
    }

    string NightSummary
    {
        get
        {
            string sale = HouseClaimed ? $"金星を確保　当夜売上 {receipts:N0} 円" : $"金星の伝票　未回収 {ledger.Receipts:N0} 円";
            string shift = ledger.CrewShift == 1 ? "助っ人・鉄　打たれ強い" :
                ledger.CrewShift == 2 ? "助っ人・鈴　打たれ強い" : "辰たち六人";
            return sale + "　／　" + shift;
        }
    }

    void LoadCampaign()
    {
        string directory=Environment.GetEnvironmentVariable("KINSEI_SAVE_DIRECTORY");
        ledgerStore = new KinseiLedgerStore(string.IsNullOrWhiteSpace(directory)?Application.persistentDataPath:directory);
        try
        {
            ledger = ledgerStore.Load();
            CampaignError = ledgerStore.Recovered ? "予備の帳面から復元しました" : "";
        }
        catch (Exception e) when (LedgerFailure(e)) { ShowLedgerError(e); }
    }

    static bool LedgerFailure(Exception e)
    {
        return e is IOException || e is InvalidDataException || e is UnauthorizedAccessException ||
            e is ArgumentException || e is OverflowException || e is System.Security.SecurityException;
    }

    void ShowLedgerError(Exception e)
    {
        CampaignError = "帳面を読み書きできません。空き容量と保存先を確認して再試行してください。";
        Debug.LogWarning("KINSEI 台帳 " + e.Message);
    }

    bool BeginCampaign(bool finalNight)
    {
        if (pendingEnding != null && !BookReturn()) return false;
        try
        {
            ledger = ledgerStore.Change(data => {
                if(finalNight && !(data.kajiPromise && data.stagePromise))throw new InvalidDataException("最終夜の約束が不足しています");
                data.nights = checked(data.nights + 1);
            });
            receipts = 0;
            CampaignError = ledgerStore.Recovered ? "予備の帳面から復元しました" : "";
            return true;
        }
        catch (Exception e) when (LedgerFailure(e)) { ShowLedgerError(e); return false; }
    }

    string CrewName(int index, string original)
    {
        if (ledger.CrewShift == 1 && index == 4) return "鉄";
        if (ledger.CrewShift == 2 && index == 5) return "鈴";
        return original;
    }

    Vector3 CrewPosition(int index, Vector3 original)
    {
        if (index == 0 || ledger.CrewShift == 0) return original;
        original.x += (ledger.CrewShift == 1 ? -.48f : .48f);
        return original;
    }

    Vector3 GuardPosition(int index, Vector3 original)
    {
        if (ledger.CrewShift == 0) return original;
        float flank = (ledger.CrewShift == 1 ? .65f : -.65f);
        original.x += flank;
        original.z += index == 0 ? -.45f : .4f;
        return original;
    }

    void ApplyCampaignCrew()
    {
        if (ledger.CrewShift == 1) crew[4].hp = crew[4].maxHp = 135;
        if (ledger.CrewShift == 2) crew[5].hp = crew[5].maxHp = 135;
    }

    bool ClaimHouse()
    {
        if (HouseClaimed || phase == Phase.Title || phase == Phase.Result) return false;
        receipts = ledger.Receipts;
        boxOffice.SetCollected(true);
        Say($"金星の伝票を預かった。{receipts:N0} 円は無事に帰れば帳面に載る。", 4);
        sound.Cue("dial"); Mark("house-claimed-" + receipts);
        return true;
    }

    bool BookReturn()
    {
        bool displaced = false;
        try
        {
            int night = ledger.nights;
            ledger = ledgerStore.Change(data =>
            {
                if (data.nights != night) { displaced = true; return; }
                data.Settle(pendingEnding, receipts);
            });
        }
        catch (Exception e) when (LedgerFailure(e)) { ShowLedgerError(e); return false; }
        pendingEnding = null;
        CampaignError = displaced ? "別の出撃が始まったため、前夜の売上は失われました。" : "";
        return true;
    }

    string FinishCampaign(string id)
    {
        if (id == "loss")
        {
            string loss = HouseClaimed ? $"金星の伝票を落とした。失った売上 {receipts:N0} 円。" : "金星を確保できず、当夜の売上はゼロ。";
            receipts = 0;
            return loss;
        }
        bool final = id == "cooperative" || id == "exclusive";
        if (!final && id != "accord" && id != "pursuit") return "";
        pendingEnding = id;
        return TrySettleReturn();
    }

    string TrySettleReturn()
    {
        string id = pendingEnding;
        int amount = receipts;
        if (!BookReturn()) return "この帰還をまだ記帳できていません。";
        receipts = 0;
        if (CampaignError.Length > 0) return CampaignError;
        if(id=="cooperative" || id=="exclusive")return id=="cooperative"?"帳面に四十店共同の興行を記録した。":"帳面に金星専属の興行を記録した。";
        string tie = id == "accord" ? "辰と梶が次の興行に二千円分の客席を約束した。" : "金星の座長が次の興行に四千円分の前売りを約束した。";
        return $"帰還売上 {amount:N0} 円。{tie}";
    }

    void RetrySettlement()
    {
        if(pendingEnding==null)return;
        settlementMessage=TrySettleReturn();
        Mark(pendingEnding==null?"ledger-retry-finished":"ledger-retry-pending");
    }
}

