using UnityEngine;

namespace Evac
{
    internal sealed class SearchCase
    {
        internal readonly string title, call, reward;
        internal readonly string[] desks, notes, rooms, names, reunions;
        internal readonly int[] destinations;
        internal readonly int arrangement;
        internal SearchCase(string title,string call,string[] desks,string[] notes,string[] rooms,
            string[] names,int a,int b,string[] reunions,string reward,int arrangement)
        {
            this.title=title;this.call=call;this.desks=desks;this.notes=notes;this.rooms=rooms;
            this.names=names;destinations=new[]{a,b};this.reunions=reunions;this.reward=reward;
            this.arrangement=arrangement;
        }
        static readonly Vector3[] Positions={
            new Vector3(-11.1f,0,76),new Vector3(9.4f,0,-59),new Vector3(-10.8f,0,10),
            new Vector3(11,0,60),new Vector3(-10.6f,0,-77),new Vector3(9.9f,0,-6)
        };
        // The night and flood operations have a resident who needs equipment or a second helper.
        internal string EscortEquipment => arrangement==1?"手提げ灯":arrangement==3?"防じんマスク":
            arrangement==5?"避難用の長靴":arrangement==7?"折り畳みの杖":"";
        internal Vector3 Point(int n)
        {
            // Each annex has an east room at 60 m and a west room at 77 m. The
            // central street stays usable by the main evacuation at the same time.
            int end=(arrangement&1)==0?1:-1;
            int i=n<3?(n+arrangement/2)%3:3+(n-3+arrangement/2)%3;
            var point=Positions[i];point.z*=end;return point;
        }
    }

    internal static class SearchCases
    {
        internal static readonly SearchCase[] All={
            new SearchCase("朝市の忘れ物","商店会から、閉店の合図を聞けなかった二人の照会が入った。",
                new[]{"青果の荷受け台","配達用の伝票棚","商店会の案内板"},
                new[]{"梶さんの自転車に空の保冷箱がある。最後の配達は、氷を扱う店だった。","氷は製氷室へ直送。澄江さんは鍵を預かり、屋内で朝の放送をかけていた。","放送盤があるのは案内室。休憩所のスピーカーは受信専用だ。"},
                new[]{"製氷室","休憩所","案内室"},new[]{"配達員の梶","店番の澄江"},0,2,
                new[]{"梶が冷たいタオルを救護班へ渡した。","澄江が店の合鍵を商店会に返した。"},"商店会の救護用品",0),
            new SearchCase("消えた看板灯","商店街の照明が落ちた。閉店作業に向かった二人が集合に遅れている。",
                new[]{"電器店の作業票","交番の落とし物棚","納品口の連絡板"},
                new[]{"湊は最後に看板灯の親時計を点検。分電盤にはもう戻っていない。","紺野の傘には赤い絵の具。本人は小道具を雨から守りに行った。","親時計は時報室。小道具の引取場所は衣装庫へ変更。"},
                new[]{"衣装庫","時報室","分電室"},new[]{"時計店の湊","大道具の紺野"},1,0,
                new[]{"湊が商店街の時計を合わせた。","紺野の届けた防水布を待合の床に敷いた。"},"商店会の備蓄",1),
            new SearchCase("荷札の行き先","点呼に二人いない。倉庫の棟番号が変わった日の送り状が残っている。",
                new[]{"荷受け台帳","搬入口の当番表","返却品の検品台"},
                new[]{"吉岡の荷は冷蔵指定。旧二番棟の冷蔵機は昨日停止した。","白石は返品の封印を確認中。冷蔵庫の鍵は持っていない。","返品窓口は検品室。動いている冷蔵機は低温庫に一台だけ。"},
                new[]{"空き冷蔵棟","検品室","低温庫"},new[]{"運転手の吉岡","検品係の白石"},2,1,
                new[]{"吉岡が次の搬入便の鍵を渡した。","白石の検品票で医療品の箱を開けられた。"},"倉庫の医療品",2),
            new SearchCase("夜勤明けの伝言","交代の二人が工具を返しに入った。夜勤棟は停電し、呼出器が使えない。",
                new[]{"夜勤の交代帳","工具返却の窓口","予備灯の貸出台"},
                new[]{"松原は回転を止めてから切り粉を片付ける、と書いた。","直江の工具札は充電器に付いたまま。本人が借りたのは検電器だ。","旋盤室に切り粉の回収箱、受電室に絶縁手袋の持出記録がある。"},
                new[]{"旋盤室","充電庫","受電室"},new[]{"工員の松原","保全係の直江"},0,2,
                new[]{"松原が工具を片手ずつ班員に預けた。","直江が絶縁手袋を整備班へ返した。"},"整備棟の資材",3),
            new SearchCase("終電の遺失物","駅務室に親子から別々の伝言が入った。構内放送はホームまでしか届かない。",
                new[]{"乗換えの掲示板","駅務室の伝言箱","手荷物の引渡簿"},
                new[]{"理央は黄色い傘を届けた後、案内係と遺失物の窓口へ向かった。","父親の進は拾得物窓口に来ていない。「お迎えの放送を頼む」と伝言した。","構内マイクは放送室。待合室にもスピーカーはあるが放送はできない。"},
                new[]{"待合室","放送室","拾得物室"},new[]{"理央","父親の進"},2,1,
                new[]{"理央は救護班と父親を待てるようになった。","進は家族の名を係員に告げ、再会の受付を済ませた。"},"駅の救護箱",4),
            new SearchCase("水音の向こう","地下の防水扉が閉まる前に、清掃係と点検係が別の階段へ入った。",
                new[]{"水位の記録台","清掃用具の返却棚","ポンプの交代表"},
                new[]{"柳はポンプの振動を確かめに行った。地下の計測箱には遠隔計しかない。","塔子の台車に濡れた毛布が戻っている。乾いた分を取りに行くと伝えていた。","乾燥棚は洗濯室。駆動軸を触って点検できるのは機械室だ。"},
                new[]{"機械室","洗濯室","計測箱"},new[]{"点検係の柳","清掃係の塔子"},0,1,
                new[]{"柳が排水の記録を引き継いだ。","塔子が毛布を配る場所まで戻った。"},"地下の非常用品",5),
            new SearchCase("途切れた河川無線","河川敷から呼出符号が二つ聞こえた。古い中継所の地図には移設前の表示がある。",
                new[]{"無線の日誌","工具船の貸出台","水位標の巡回表"},
                new[]{"新田の声に潮位警報のベルが重なる。ベルは堤防の観測室に移した。","佐伯は救命胴衣を借りた。艇を出さず、繋留索を点検すると話した。","艇庫は空。索は舟番小屋で結び直す。古い無線室はまだ無人。"},
                new[]{"旧無線室","舟番小屋","観測室"},new[]{"観測員の新田","舟番の佐伯"},2,1,
                new[]{"新田が次の潮位を無線に載せた。","佐伯が桟橋の人数を班に知らせた。"},"河岸の救助用品",6),
            new SearchCase("最後の交代要員","最後の車列を出す前に、車庫の呼名に返事のなかった二人を迎えに行く。",
                new[]{"運転士の交番表","補給品の持出票","回送の発車票"},
                new[]{"鈴は運転から降りたあと、車掌鞄を保管している。車両は既に空だ。","稲葉が予備の毛布を一束受け取った。仮眠明けの人を起こしに向かった。","鞄は点呼室へ返す決まり。休憩所は閉鎖し、仮眠台を宿直室に移した。"},
                new[]{"宿直室","点呼室","休憩所"},new[]{"車掌の鈴","当直の稲葉"},1,0,
                new[]{"鈴が発車票の渡し先を引き受けた。","稲葉が宿直室の最後の鍵を返した。"},"車庫の非常物資",7)
        };
    }
}
