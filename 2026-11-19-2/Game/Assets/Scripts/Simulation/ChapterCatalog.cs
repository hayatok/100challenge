using UnityEngine;

namespace Evac
{
    internal enum ChapterMethod { Survey, Transfer, Triage, Escort, Repair, Signal }
    internal enum ChapterBenefit { Medicine, Freight, Crew, Passage, Tools, Vehicle, Reserve, Drain }

    internal sealed class ChapterOption
    {
        public readonly string title,residentName;
        public readonly ChapterMethod method;
        public readonly Vector3 source, destination;
        public readonly ChapterBenefit benefit;
        public ChapterOption(string title,ChapterMethod method,Vector3 source,Vector3 destination,ChapterBenefit benefit,string residentName=null)
        {
            this.title=title;this.method=method;this.source=source;this.destination=destination;this.benefit=benefit;this.residentName=residentName;
        }
    }

    internal sealed class ChapterBeat
    {
        public readonly string title, incident;
        public readonly ChapterOption[] options;
        public ChapterBeat(string title,string incident,ChapterOption a,ChapterOption b)
        {this.title=title;this.incident=incident;options=new[]{a,b};}
    }

    internal sealed class ChapterPlan
    {
        public readonly ChapterBeat forward,retreat;
        public ChapterPlan(ChapterBeat forward,ChapterBeat retreat){this.forward=forward;this.retreat=retreat;}
    }

    internal static partial class ChapterCatalog
    {
        internal static Vector3 P(float x,float z)=>new Vector3(x,0,z);
        internal static ChapterPlan For(int index)=> index<4 ? Early[index] : Late[index-4];
        static readonly ChapterPlan[] Early={
            new ChapterPlan(
                new ChapterBeat("開場前の朝市","青果店に避難者の名簿、バス停には道を知る店主がいます。先に頼る相手を決めてください。",
                    new ChapterOption("店先と停留所の名簿を照合",ChapterMethod.Survey,P(-7,7),P(6,-12),ChapterBenefit.Passage),
                    new ChapterOption("店主を案内役に迎える",ChapterMethod.Escort,P(-9,12),P(3,-10),ChapterBenefit.Crew,"青果店の吉田")),
                new ChapterBeat("市場を閉める","最後の車内から、市場に残す物資について連絡が入りました。",
                    new ChapterOption("救護所に常備薬を届ける",ChapterMethod.Transfer,P(-8,3),P(4,-12),ChapterBenefit.Medicine),
                    new ChapterOption("足を痛めた連絡員を搬送",ChapterMethod.Triage,P(8,7),P(5,-12),ChapterBenefit.Crew,"連絡員の今井"))),
            new ChapterPlan(
                new ChapterBeat("夜の開店準備","アーケードの東西で呼び声がします。救護窓口か避難放送のどちらかを先に開けます。",
                    new ChapterOption("薬剤師を救護窓口へ案内",ChapterMethod.Escort,P(-9,57),P(-4,12),ChapterBenefit.Medicine,"薬剤師の望月"),
                    new ChapterOption("両側の放送盤を接続",ChapterMethod.Signal,P(8,20),P(-9,-20),ChapterBenefit.Passage)),
                new ChapterBeat("商店会の引き渡し","通りには荷物を守る商店主と、修理用の発電機が残っています。",
                    new ChapterOption("鍵を預かり商店主と退避",ChapterMethod.Escort,P(9,-58),P(3,-16),ChapterBenefit.Crew,"商店主の中川"),
                    new ChapterOption("発電機に交換部品を組む",ChapterMethod.Repair,P(8,-12),P(-8,19),ChapterBenefit.Tools))),
            new ChapterPlan(
                new ChapterBeat("荷受け場の検収","重い箱を先に動かすか、計量台を修復して積み荷を確かめるかを選んでください。",
                    new ChapterOption("現物を仕分け場へ搬送",ChapterMethod.Transfer,P(9,58),P(2,-10),ChapterBenefit.Freight),
                    new ChapterOption("計量台の駆動部を交換",ChapterMethod.Repair,P(-10,11),P(7,23),ChapterBenefit.Tools)),
                new ChapterBeat("最後の荷札","空いた荷台に載せられるのは、構内作業員の救護班か予備弾薬です。",
                    new ChapterOption("負傷した作業員を救護班へ",ChapterMethod.Triage,P(-9,-73),P(-3,-16),ChapterBenefit.Medicine,"作業員の遠藤"),
                    new ChapterOption("予備弾薬を積む",ChapterMethod.Transfer,P(8,55),P(-5,-15),ChapterBenefit.Reserve))),
            new ChapterPlan(
                new ChapterBeat("夜勤者の点呼","夜勤の交代までに整備棟で事故が起きました。作業員と駆動装置は別々の棟にいます。",
                    new ChapterOption("巻き込まれた作業員を搬送",ChapterMethod.Triage,P(-9,75),P(4,-14),ChapterBenefit.Crew,"夜勤の竹内"),
                    new ChapterOption("油圧系統を復旧",ChapterMethod.Repair,P(8,12),P(-8,23),ChapterBenefit.Tools)),
                new ChapterBeat("構内の施錠","車庫から出た後に残る人のため、車両を直すか構内の連絡回線を維持します。",
                    new ChapterOption("車両の応急整備",ChapterMethod.Repair,P(-6,-20),P(7,-15),ChapterBenefit.Vehicle),
                    new ChapterOption("両棟の当直に連絡",ChapterMethod.Signal,P(9,56),P(-10,-73),ChapterBenefit.Passage)))
        };
    }
}
