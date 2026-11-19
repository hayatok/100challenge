using System;
using UnityEngine;

namespace Evac
{
    internal enum RouteTask { Assembly, Search, Freight, Workshop, Platform, Flood, Relay, Convoy }

    internal sealed class RoutePlan
    {
        internal readonly RouteTask task;
        internal readonly string title, district, briefing;
        internal readonly Vector3 entrance, assembly, gate, exit, depot, cache, works;
        internal readonly int population, quota, wounded;
        internal readonly float waveInterval;
        internal RoutePlan(RouteTask operation, string name, string area, string instructions, int count, int required, int injured,
            Vector2 threat, Vector2 civilians, Vector2 passage, Vector2 door, Vector2 home, Vector2 freight, Vector2 plant, float wave)
        {
            task = operation; title = name; district = area; briefing = instructions;
            population = count; quota = required; wounded = injured; waveInterval = wave;
            entrance = Floor(threat); assembly = Floor(civilians); gate = Floor(passage); exit = Floor(door);
            depot = Floor(home); cache = Floor(freight); works = Floor(plant);
        }
        static Vector3 Floor(Vector2 p) => new Vector3(p.x, 0, p.y);
        static Vector2 P(float x, float z) => new Vector2(x,z);

        internal static readonly RoutePlan[] All =
        {
            new RoutePlan(RouteTask.Assembly,"朝市の集合場所","商店街","青果店で住民がバスを待っています。",
                8,5,1,P(0,30),P(-8,2),P(-2,-3),P(8,-15),P(4,-12),P(-12,10),P(-4,-6),26),
            new RoutePlan(RouteTask.Search,"閉店後のアーケード","商店街","住民が通りの両側に取り残されています。最後尾の負傷者には肩を貸してください。",
                14,9,3,P(8,31),P(-11,10),P(0,-1),P(9,-19),P(5,-15),P(13,9),P(-5,-5),23),
            new RoutePlan(RouteTask.Freight,"荷受けヤード","物流倉庫","荷受け場の資材を集積所に届けて積み込み橋を架けます。誘導班は住民を橋まで案内してください。",
                18,12,2,P(-9,30),P(7,10),P(3,-4),P(-9,-20),P(-3,-13),P(12,5),P(-4,-7),23),
            new RoutePlan(RouteTask.Workshop,"夜勤の整備棟","物流倉庫","整備班を故障した巻き上げ機へ。シャッターが開けば構内の住民を外へ誘導できます。",
                22,15,4,P(12,31),P(-10,11),P(-1,-2),P(10,-19),P(4,-14),P(-11,4),P(-4,3),21),
            new RoutePlan(RouteTask.Platform,"臨時列車","環状線駅","排水と昇降機に電源を。整備班が予備電源を直すと防護柵も使えます。列車には64人が乗れます。",
                64,40,6,P(-3,32),P(-10,17),P(-3,3),P(13,-14),P(6,-13),P(-12,-5),P(-6,-1),19),
            new RoutePlan(RouteTask.Flood,"冠水した地下連絡路","環状線駅","地下の水を抜き、昇降機を動かしてください。地下に残る住民がいる間は水位を監視します。",
                36,24,6,P(10,31),P(-11,18),P(-4,4),P(13,-14),P(6,-13),P(-12,-5),P(-6,-1),18),
            new RoutePlan(RouteTask.Relay,"河川敷の中継所","車両基地","資材を運び、整備班が中継所を復旧すると輸送車が到着します。住民を河川敷から収容してください。",
                30,20,5,P(-9,32),P(9,16),P(2,0),P(-10,-21),P(-4,-15),P(11,6),P(-5,2),18),
            new RoutePlan(RouteTask.Convoy,"最後の車列","車両基地","整備班が資材で出発信号を復旧します。警備班は合流点を、誘導班は最後の車列を守ってください。",
                48,32,8,P(0,32),P(-10,17),P(0,1),P(10,-21),P(5,-15),P(-12,5),P(-4,3),16)
        };
    }
}
