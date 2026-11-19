using UnityEngine;

namespace Evac
{
    internal static partial class ChapterCatalog
    {
        // Underpass, engine house and riverside are open to both foot patrols and dispatched teams.
        internal static readonly ChapterPlan[] Late =
        {
            new ChapterPlan(
                new ChapterBeat("改札の向こう","ホームの表示が消え、二つの駅務室に別々の情報が残った。",
                    new ChapterOption("駅員をホームへ案内",ChapterMethod.Escort,new Vector3(-10,0,76),new Vector3(-8,0,13),ChapterBenefit.Crew,"駅員の三浦"),
                    new ChapterOption("上下線の札を照合",ChapterMethod.Survey,new Vector3(10,0,-60),new Vector3(-10,0,76),ChapterBenefit.Passage)),
                new ChapterBeat("終列車の後ろ","発車待ちの車内に照明が戻った。反対のホームからも合図が見える。",
                    new ChapterOption("両端から発車確認",ChapterMethod.Signal,new Vector3(-10,0,-77),new Vector3(10,0,60),ChapterBenefit.Reserve),
                    new ChapterOption("担架の乗客を迎える",ChapterMethod.Triage,new Vector3(10,0,-60),new Vector3(8,0,-12),ChapterBenefit.Medicine,"乗客の松浦"))),
            new ChapterPlan(
                new ChapterBeat("水の来る方","地下入口に水が流れ込んだ。水位の記録は二か所に分かれている。",
                    new ChapterOption("上流の記録を照合",ChapterMethod.Survey,new Vector3(-10,0,77),new Vector3(-6,0,-2),ChapterBenefit.Drain),
                    new ChapterOption("予備の制御器を交換",ChapterMethod.Repair,new Vector3(10,0,-60),new Vector3(-9,0,19),ChapterBenefit.Tools)),
                new ChapterBeat("まだ灯る窓","ポンプを止める直前、保守員の灯りがガラス越しに動いた。",
                    new ChapterOption("保守員と地上へ戻る",ChapterMethod.Escort,new Vector3(-10,0,-77),new Vector3(10,0,60),ChapterBenefit.Crew,"保守員の相田"),
                    new ChapterOption("予備電池を引き渡す",ChapterMethod.Transfer,new Vector3(10,0,60),new Vector3(5,0,-14),ChapterBenefit.Freight))),
            new ChapterPlan(
                new ChapterBeat("堤防沿いの詰所","堤防の下で無線が途切れた。車両基地から川上と川下を同時には見渡せない。",
                    new ChapterOption("上下流で合図を合わせる",ChapterMethod.Signal,new Vector3(-10,0,77),new Vector3(10,0,-60),ChapterBenefit.Passage),
                    new ChapterOption("途切れた中継器を修復",ChapterMethod.Repair,new Vector3(10,0,60),new Vector3(-5,0,2),ChapterBenefit.Tools)),
                new ChapterBeat("河川敷の最後尾","岸の見回りを終えた班が戻ってきた。資材と負傷者を別々に引き取ってほしい。",
                    new ChapterOption("水門の負傷者を搬送",ChapterMethod.Triage,new Vector3(-10,0,77),new Vector3(-4,0,-15),ChapterBenefit.Medicine,"水門係の中野"),
                    new ChapterOption("回収品を車庫へ運ぶ",ChapterMethod.Transfer,new Vector3(10,0,-60),new Vector3(-10,0,77),ChapterBenefit.Vehicle))),
            new ChapterPlan(
                new ChapterBeat("出庫記録","運行表にはまだ空きがある。車庫の整備員と物資のどちらを先に迎えるか。",
                    new ChapterOption("整備員と車庫へ戻る",ChapterMethod.Escort,new Vector3(10,0,60),new Vector3(-10,0,-77),ChapterBenefit.Vehicle,"整備員の広瀬"),
                    new ChapterOption("積み残した資材を渡す",ChapterMethod.Transfer,new Vector3(-10,0,-77),new Vector3(3,0,-13),ChapterBenefit.Freight)),
                new ChapterBeat("車列の消えたあと","最後の車が出る。先頭車にも後尾にも、こちらからの返事が必要だ。",
                    new ChapterOption("車列の両端を確認",ChapterMethod.Signal,new Vector3(10,0,60),new Vector3(-10,0,-77),ChapterBenefit.Crew),
                    new ChapterOption("取り残された一人と帰る",ChapterMethod.Triage,new Vector3(-10,0,77),new Vector3(5,0,-15),ChapterBenefit.Medicine,"運転手の原")))
        };
    }
}
