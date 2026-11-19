using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        internal bool TryFieldNavigation(out string action, out string destination, out Vector3 point)
            => TryFieldNavigation(out action, out destination, out point, out _);

        internal bool TryFieldNavigation(out string action, out string destination, out Vector3 point, out bool marketTask)
        {
            var route = sim.FieldNavigation(Current, out marketTask);
            action = route.action;
            destination = route.destination;
            point = route.point.GetValueOrDefault();
            return route.point.HasValue;
        }
    }

    public partial class GameSim
    {
        internal (string action, string destination, Vector3? point) FieldNavigation(Unit u)
            => FieldNavigation(u, out _);

        internal (string action, string destination, Vector3? point) FieldNavigation(Unit u, out bool marketTask)
        {
            marketTask = false;
            if (!IsReady || u == null || !u.active || !IsSoldier(u)) return ("待機", "", null);
            if (ColumnsActive)
            {
                for (int c = 0; c < ColumnCount; c++)
                {
                    var line = Line(c);
                    if (line.finished) continue;
                    if (line.operatorId == u.id || MarketColumn && !line.open && line.marketManualOpener == u.id + 1)
                    {
                        marketTask = MarketColumn;
                        return MarketColumn ? ("横戸を解錠", "市場横戸", MarketPassage.Gate) :
                            (ColumnActionLabel(c, 4), c == 0 ? "放送盤" : "防火扉の操作盤", ColumnControlPoint(c));
                    }
                    if (line.pickup == u.id && StretcherPatient(c) is Unit rider)
                        return ("担架を引き受ける", rider.name, rider.pos);
                    if (line.medic == u.id && ColumnPatient(c) is Unit patient)
                        return ("負傷者を手当て", patient.name, patient.pos);
                    if (line.carrier == u.id && line.lead != u.id)
                    {
                        var guide = Find(line.lead);
                        if (line.held || guide == null) return ("担架で待機", "", null);
                        return ("担架で同行", guide.name, guide.pos);
                    }
                    if (line.lead == u.id && !line.held)
                    {
                        marketTask = MarketColumn;
                        if (!line.joined) return ("付添のため合流", ColumnTitle(c), ColumnPosition(c));
                        return ColumnRouteNavigation(c, line);
                    }
                }
            }

            if (ChapterField && ChapterChoice >= 0)
            {
                int posting = ChapterAssigned(u.squad);
                bool manual = u == Controlled && Chapter.manual == u.id + 1;
                if (ChapterRunner == u || (posting >= 0 || manual) &&
                    (ChapterRunner == null || ChapterNeedsSupport))
                {
                    bool support = !manual && posting >= 0 && ChapterSupport(u, posting);
                    var (action, destination) = ChapterNavigationLabel(support);
                    return (action, destination, ChapterPoint(support));
                }
            }
            if (WingActive && !WingComplete)
            {
                int station = WingAssignment(u.squad);
                if (station >= 0 && Wing.workers[u.squad] == u.id + 1)
                    return (WingAction(station, Wing.jobs[u.squad] % 2), WingRoomName(station), WingPosition(station));
                if (Wing.leader == u.id)
                    return (WingResidentName + "に同行", WingRoomName(4), WingPosition(4));
                if (Wing.freightRunner == u.id && WingHasFreight && (WingRegion == 0 || WingRegion == 1))
                {
                    int stop = WingRegion == 0 ? 2 : 5;
                    return (WingFreightLabel + "を搬送", WingRoomName(stop), WingPosition(stop));
                }
            }

            var group = state.squads[u.squad];
            var brain = Brain(u);
            if (HasRequestPoint && (state.requestCarrier == u.id ||
                brain.escort >= 0 && brain.escort == state.requestActor ||
                group.requestDuty && !brain.cargo && brain.escort < 0 && state.requestCarrier < 0))
                return (RequestObjective, RequestPropLabel, RequestPoint);
            if (Find(brain.escort) is Unit civilian && civilian.active)
            {
                var memory = Brain(civilian);
                bool atGate = memory.route < 1 && !FieldPickup(civilian, memory);
                return (civilian.name + "に同行", atGate ? "通過地点" : "乗車口", atGate ? memory.personalGate : Door(civilian));
            }
            if (brain.cargo) return (CargoLabel + "を搬送", "集積所", ActiveDepot);
            if (ChapterField && ChapterChoice < 0) return ("現場方針を決める", "", null);
            if (state.beacon != null && Lamp.carrier == u.id) return (BeaconName(u.squad) + "を設置", "設置地点", Lamp.destination);
            if (AlarmActorId == u.id) return ("警報を作動", AlarmName, AlarmPoint);
            var waypoints = Waypoints(u.squad);
            int i = WaypointIndex(u);
            if (waypoints != null && i >= 0 && i < waypoints.Length)
                return ("経由地へ移動", "経由地 " + (i + 1), waypoints[i]);
            int search = SearchPosting(u.squad);
            if (search >= 0) return ("捜索任務", SearchTaskName(search), SearchPoint(search));
            int district = DistrictAssignment(u.squad);
            if (district >= 0) return ("地区任務", DistrictName(district), DistrictPosition(district));

            var market = MarketLine;
            if (ColumnsActive && market != null && market.open && market.marketOpener == u.id + 1 &&
                !market.finished && !market.held && market.route == 1)
            {
                marketTask = true;
                return ColumnRouteNavigation(0, market);
            }
            if (market != null && market.finished && market.marketFinishedAt > 0 && Elapsed - market.marketFinishedAt < 6 &&
                (market.marketOpener == u.id + 1 || market.marketLastGuide == u.id + 1))
                return (ColumnStatus(0), "", null);

            if (!group.assigned) return ("待機", "", null);
            switch (OrderFor(u.squad))
            {
                case SquadOrder.Guard: return ("警戒", "警戒地点", group.destination);
                case SquadOrder.Supply: return ("補給", SupplyAtPost(u.squad) ? ChapterPostLabel : "集積所",
                    SupplyAtPost(u.squad) ? ChapterPostPosition : ActiveDepot);
                case SquadOrder.Engineer:
                    if (!SectorDispatched(u.squad)) return ("待機", "", null);
                    if (brain.route == 0) return ("整備に向かう", "指示地点", group.destination);
                    switch (EngineerTarget(brain, out var work))
                    {
                        case EngineerTask.Collect: return (CargoLabel + "を回収", "保管場所", work);
                        case EngineerTask.Repair: return ("設備を修理", "修理現場", work);
                        case EngineerTask.Build: return ("施設を建設", "建設現場", work);
                        case EngineerTask.Return: return ("集積所へ戻る", "集積所", work);
                        default: return ("資材を待つ", "", null);
                    }
                case SquadOrder.Guide:
                    if (brain.route == 0) return ("住民を誘導", "指示地点", group.destination);
                    var target = GuideTarget(u, out _);
                    if (target != null) return ("住民を迎えに行く", target.name, target.pos);
                    return ("住民を待つ", "通過地点", ActiveGate);
                default: return ("移動", "指示地点", group.destination);
            }
        }

        (string action, string destination) ChapterNavigationLabel(bool support)
        {
            if (Chapter.dropped) return ("荷物を受け取る", "荷物の場所");
            if (ChapterNeedsSupport)
            {
                if (Chapter.portableSignal) return ("携帯中継器を運ぶ", "反対側の合図地点");
                return ("合図を送る", support ? "反対側の合図地点" : "最初の合図地点");
            }
            if (Chapter.stage == 0)
            {
                if (ChapterResident is Unit resident)
                    return (ChapterJob.method == ChapterMethod.Triage ? "負傷者に近づく" : "合流する", resident.name);
                if (ChapterJob.method == ChapterMethod.Survey)
                    return ("名簿を確認", state.index == 0 && ChapterPhase == 1 ? "青果店の店先" : "最初の記録地点");
                return ("受け取りに向かう", ChapterJob.method == ChapterMethod.Repair ? "部品の受取場所" : "荷物の受取場所");
            }
            switch (ChapterJob.method)
            {
                case ChapterMethod.Survey:
                    return ("記録を照合", state.index == 0 && ChapterPhase == 1 ? "バス停" : "照合先");
                case ChapterMethod.Escort:
                    return ("同行する", state.index == 0 && ChapterPhase == 1 ? "バス停そばの合流地点" : "同行先");
                case ChapterMethod.Triage:
                    return ("負傷者を搬送", "受け入れ先");
                case ChapterMethod.Repair:
                    return (ChapterInstruction, "修理現場");
                default:
                    return ("荷物を届ける", "受け渡し場所");
            }
        }

        (string action, string destination, Vector3? point) ColumnRouteNavigation(int c, EvacuationLine line)
        {
            if (MarketColumn && line.route == 1 && !line.marketBypass)
            {
                if (!line.open && WaitingAtMarketQueue(line)) return ("横戸の解錠を待つ", "青果店の軒下", MarketMeetingPoint);
                if (line.open && (line.leg == 0 || line.leg == 1 && line.marketStep <= 1))
                {
                    int remaining = 0;
                    foreach (int id in line.people)
                        if (Find(id) is Unit person && person.active && person.pos.z >= MarketPassage.Gate.z) remaining++;
                    if (remaining > 0) return ("店主の通過を確認　あと" + remaining + "人", "市場横戸", MarketPassage.Gate);
                }
                if (line.open && line.leg >= 1)
                    return ("店主を乗車口へ誘導", "バス乗車口", ActiveExit);
            }
            return (ColumnTitle(c) + "に付添", ColumnNextStop(c), ColumnDestination(c));
        }
    }
}
