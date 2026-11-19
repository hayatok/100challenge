using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        static readonly string[] FieldOrders = { "移動", "警戒", "誘導", "整備", "補給" };

        int BodySize => G.LargeText ? 20 : 17;

        bool directRadioOpen;

        bool GuideVisible => Time.unscaledTime < guideUntil;
        void ToggleGuide() => guideUntil = GuideVisible ? 0 : float.PositiveInfinity;

        static string Key(ControlAction action) => ControlPreferences.KeyLabel(action);
        static string MovementKeys => Key(ControlAction.Forward)+Key(ControlAction.StrafeLeft)+Key(ControlAction.Backward)+Key(ControlAction.StrafeRight);
        const float BoardHeight = 84;

        void DrawBoard()
        {
            float height = BoardHeight;
            const float top = 12, gap = 6, pauseWidth = 82, bookWidth = 118, statusWidth = 249;
            float pauseX = w - 14 - pauseWidth;
            float bookX = pauseX - bookWidth - gap;
            float statusX = (G.IsDuty ? pauseX : bookX) - statusWidth - gap;
            float missionWidth = Mathf.Min(statusX - 24, 432);
            Rect mission = R(14, top, missionWidth, height);
            Instrument(mission);
            Fill(R(mission.x, mission.y, 4, mission.height), Rail);

            string section = ChapterTask ? Field.ChapterTitle : G.SectorCount > 0 ? G.SectorName : FieldName;
            bool hasDestination = G.TryFieldNavigation(out string action, out string destination, out _);
            if (G.Mode != "FPS") CommandSituation(section, hasDestination, ref action, ref destination);
            else if (!hasDestination && G.IsDuty) action = G.Objective;
            if (string.IsNullOrEmpty(action)) action = section;
            if (destination == action) destination = "";
            string task = string.IsNullOrEmpty(destination) ? action : action + "　／　" + destination;
            string banner = string.IsNullOrEmpty(G.SoldierName) || ChapterTask && G.Mode != "FPS" ? G.DistrictName(G.MissionIndex) :
                G.SoldierName + "　／　" + G.DistrictName(G.MissionIndex);
            if (G.IsDuty) banner += $"　救援当直 {G.DutyIndex + 1:00}号";
            string location = FieldLocation(section);
            string phase = ChapterTask ? (Field.ChapterPhase == 1 ? "前哨" : "撤収") : location;
            if (task != phase) banner += "　" + phase;
            float textWidth = mission.width - 24;
            Text(R(26, top + 3, textWidth, 25), banner,
                FieldLineSize(banner, textWidth, G.LargeText ? 17 : 14, false), Mist);
            Rect taskLine = R(26, top + 27, mission.width - 24, height - 31);
            int taskSize = G.LargeText ? 22 : 20;
            measurement.text = task;
            if (!string.IsNullOrEmpty(destination) && TextStyle(taskSize, true, TextAnchor.MiddleLeft).CalcSize(measurement).x > textWidth)
            {
                float lineHeight = taskLine.height / 2;
                Text(R(taskLine.x, taskLine.y, textWidth, lineHeight), action,
                    FieldLineSize(action, textWidth, G.LargeText ? 20 : 18, true), Cream, true);
                Text(R(taskLine.x, taskLine.y + lineHeight, textWidth, lineHeight), destination,
                    FieldLineSize(destination, textWidth, G.LargeText ? 18 : 16, false), Mist);
            }
            else if (TextStyle(taskSize, true, TextAnchor.MiddleLeft).CalcSize(measurement).x > textWidth)
            {
                Paragraph(taskLine, task, G.LargeText ? 19 : 16, Cream);
            }
            else
            {
                Text(taskLine, task, FieldLineSize(task, textWidth, taskSize, true), Cream, true);
            }

            Rect status = R(statusX, top, statusWidth, height);
            Instrument(status);
            string label = G.IsDuty ? "救出人数" : "乗車人数";
            bool hasQuota = G.Needed > 0;
            if (hasQuota) label += "／目標";
            string count = hasQuota ? $"{G.Saved} / {G.Needed}" : $"{G.Saved}";
            int labelSize = G.LargeText ? 16 : 14;
            int digits = G.LargeText ? 31 : 28;
            Text(R(statusX + 13, top + 3, 139, 25), label, labelSize, Mist, true);
            bool goalMet = hasQuota && G.Saved >= G.Needed;
            Text(R(statusX + 13, top + 27, 139, 36), count, digits, goalMet ? Green : Amber, true);
            Text(R(status.xMax - 108, top + 3, 95, 25), "残り時間", labelSize, Mist, false, TextAnchor.MiddleRight);
            Text(R(status.xMax - 108, top + 27, 95, 36), Clock(G.Remaining), digits,
                G.Remaining < 30 ? new Color32(255, 160, 132, 255) : Cream, true, TextAnchor.MiddleRight);
            if (hasQuota)
                Bar(R(statusX + 13, status.yMax - 9, statusWidth - 26, 4), (float)G.Saved / G.Needed, goalMet ? Green : Amber);

            float buttonHeight = G.TouchUI ? 56 : 40;
            if (Button(R(pauseX, top, pauseWidth, buttonHeight), "一時停止", dark: true)) Submit(G.Pause);
            if (!G.IsDuty && Button(R(bookX, top, bookWidth, buttonHeight), "作戦手帳", dark: true))
                ToggleBook();
            if (G.TouchUI)
            {
                Rect modeLabel = R(pauseX, top + 59, pauseWidth, 25);
                Instrument(modeLabel);
                Text(modeLabel, G.Mode == "FPS" ? "直接操作" : "部隊指揮", G.LargeText ? 17 : 15, Cream,
                    true, TextAnchor.MiddleCenter);
            }
            else if (Button(R(pauseX, top + 44, pauseWidth, 32), "F1 操作", selected: GuideVisible, dark: true))
                ToggleGuide();

#if UNITY_WEBGL && EVAC_WEB_TEST && !UNITY_EDITOR
            ReportFieldHud(task, count, banner);
#endif
        }

        void CommandSituation(string section, bool hasDestination, ref string action, ref string destination)
        {
            if (ChapterTask)
            {
                action = section;
                destination = "";
                if (Field.ChapterChoice < 0) return;
                destination = Field.ChapterOptionTitle(Field.ChapterChoice);
                return;
            }

            if (G.CanDepart)
            {
                action = "出発準備完了";
                destination = "";
                return;
            }
            if (G.FleetBlocked)
            {
                action = "本線は通行止め";
                destination = "";
                return;
            }
            if (hasDestination) return;
            if (!G.IsDuty && Field.ColumnsActive && !Field.ColumnsComplete)
            {
                int column = ActiveColumn();
                action = Field.ColumnTitle(column);
                destination = Field.ColumnStatus(column);
                return;
            }
            if (!G.IsDuty && G.FieldOutcome(G.CurrentDistrict) == 0)
            {
                int assigned = AssignedDistrictSquad();
                if (assigned >= 0)
                {
                    action = G.SquadName(assigned) + "が対応中";
                    destination = G.FieldDistrict(G.CurrentDistrict);
                    return;
                }
                action = G.FieldTask(G.CurrentDistrict);
                destination = "";
                return;
            }
            string objective = G.Objective;
            string prefix = section + "　";
            action = objective.StartsWith(prefix, System.StringComparison.Ordinal) ? objective.Substring(prefix.Length) : objective;
            destination = "";
        }

        int FieldLineSize(string line, float width, int size, bool bold)
        {
            measurement.text = line;
            while (size > 14 && TextStyle(size, bold, TextAnchor.MiddleLeft).CalcSize(measurement).x > width)
                size--;
            return size;
        }

        string FieldLocation(string section)
        {
            var actor = G.Current;
            if (!Field.WingActive || actor == null || !actor.active || actor.pos.z < 93 || Mathf.Abs(actor.pos.x) >= 14.5f)
                return section;
            if (Mathf.Abs(actor.pos.x) <= 3.5f) return Field.WingTitle;
            int row = actor.pos.z < 110 ? 0 : actor.pos.z < 130 ? 1 : 2;
            return Field.WingRoomName(row * 2 + (actor.pos.x < 0 ? 0 : 1));
        }

        void Instrument(Rect box)
        {
            Panel(box, Case, Edge, true);
            Fill(R(box.x + 1, box.y + 1, box.width - 2, 2), new Color32(50, 60, 57, 255));
            Fill(R(box.x + 5, box.yMax - 7, 3, 3), Edge);
            Fill(R(box.xMax - 8, box.yMax - 7, 3, 3), Edge);
        }

        int ActiveColumn()
        {
            if (lastColumn >= 0 && lastColumn < Field.ColumnCount && !Field.ColumnFinished(lastColumn)) return lastColumn;
            for (int column = 0; column < Field.ColumnCount; column++)
                if (!Field.ColumnFinished(column)) return column;
            return 0;
        }

        int AssignedDistrictSquad()
        {
            for (int squad = 0; squad < 3; squad++)
                if (G.SquadPosting(squad) == G.CurrentDistrict) return squad;
            return -1;
        }

        void DrawTransportAction()
        {
            if (G.CanDepart)
                DrawTransportPin(Field.ActiveExit, "出発を指示", G.Depart);
            else if (G.FleetBlocked)
                DrawTransportPin(Field.FleetBlockPoint, "本線の通行障害", () => fleetOpen = true);
            else if (!G.IsDuty && Field.ColumnsActive && !Field.ColumnsComplete)
            {
                int column = ActiveColumn();
                bool liftBlocked = G.CircuitCount > 0 && !Field.ColumnHeld(column) &&
                    Field.ColumnRoute(column) == 0 && !Field.ColumnRouteClear(column);
                if (liftBlocked)
                    DrawTransportPin(Field.ColumnDestination(column), "排水・昇降機を確認", () => fieldPanel = true);
                else
                    DrawTransportPin(Field.ColumnPosition(column), "避難隊列", () => OpenColumn(column));
            }
            else if (!G.IsDuty && G.FieldOutcome(G.CurrentDistrict) == 0 && AssignedDistrictSquad() < 0)
                DrawTransportPin(Field.DistrictPosition(G.CurrentDistrict),
                    G.FieldDistrict(G.CurrentDistrict) + "に班を派遣", OpenDispatch);
            else if (!G.IsDuty && Field.WingActive && !Field.WingComplete && G.CurrentDistrict == G.SectorCount - 1)
                DrawTransportPin(Field.WingPosition(0), "館内の救助を指揮", () => OpenWing());
        }

        void DrawTransportPin(Vector3 world, string label, System.Action activate)
        {
            Vector2 point = QuestScreen(world + Vector3.up * 1.45f);
            float width = Mathf.Min(302, Mathf.Max(136, label.Length * (G.LargeText ? 19 : 17) + 24));
            Rect box = QuestBox(point, width, G.TouchUI ? 58 : 45);
            Vector2 destination = QuestVisiblePoint(point);
            Vector2 end = new Vector2(Mathf.Clamp(destination.x, box.xMin + 8, box.xMax - 8),
                destination.y < box.center.y ? box.y : box.yMax);
            DrawMarketLine(end, destination, Amber, false);
            Outline(R(destination.x - 8, destination.y - 8, 16, 16), Amber, 3);
            if (Button(box, label, primary: true)) Submit(activate);
        }

        void DrawCommand()
        {
            DrawBoard();
            CommandPanel active = G.EditingWaypoints ? CommandPanel.Orders : commandPanel;
            if (active == CommandPanel.None && !G.PickingLamp)
            {
                DrawQuestMap();
                if (!ChapterTask) DrawTransportAction();
            }
            if (G.PickingLamp)
                Text(R(14, BoardHeight + 20, w - 28, 34), "設置する場所を選択", 19, Amber, true, TextAnchor.MiddleCenter);

            float buttonHeight = G.TouchUI ? 59 : 46;
            float bottom = h - 14 - buttonHeight;
            float rosterWidth = Mathf.Min(w * .45f, 356);
            float ordersWidth = Mathf.Min(w * .45f, 376);
            if (active == CommandPanel.Roster)
                DrawRoster(R(14, bottom - 220, rosterWidth, 210));
            else if (active == CommandPanel.Orders)
                DrawOrders(R(w - ordersWidth - 14, bottom - 238, ordersWidth, 228));
            else if (active == CommandPanel.Radio)
            {
                float width = Mathf.Min(w - 28, 520);
                DrawRadio((w - width) / 2, bottom - 10, width, "", G.Radio, true, BoardHeight + 20);
            }

            if (Button(R(14, bottom, 168, buttonHeight), "名簿　" + G.SquadName(G.SelectedSquad),
                selected: active == CommandPanel.Roster, dark: true))
                SetCommandPanel(CommandPanel.Roster);
            if (Button(R((w - 92) / 2, bottom, 92, buttonHeight), "無線",
                selected: active == CommandPanel.Radio, dark: true))
                SetCommandPanel(CommandPanel.Radio);
            if (Button(R(w - 158, bottom, 144, buttonHeight), "班への命令",
                selected: active == CommandPanel.Orders, dark: true))
                SetCommandPanel(CommandPanel.Orders);
            if (GuideVisible)
            {
                string mapControls = G.TouchUI ? "タップで地点を指示　ドラッグで地図移動" :
                    $"{MovementKeys}　地図移動　　右クリック　地点を指示　　{Key(ControlAction.SwitchView)}　直接操作";
                Rect mapGuide = R(14, BoardHeight + 19, G.TouchUI ? 345 : 508, 29);
                Fill(mapGuide, Case);
                Text(R(mapGuide.x + 9, mapGuide.y, mapGuide.width - 18, 29), mapControls, 15, Cream, true);
            }
        }

        void SetCommandPanel(CommandPanel panel)
        {
            var active = G.EditingWaypoints ? CommandPanel.Orders : commandPanel;
            if (active == CommandPanel.Orders && G.EditingWaypoints) Submit(G.EndWaypointEdit);
            commandPanel = active == panel ? CommandPanel.None : panel;
            orderPickerOpen = false;
        }

        void DrawRoster(Rect box)
        {
            Instrument(box);
            Fill(R(box.x, box.y, box.width, 3), Amber);
            float x = box.x + 10, width = box.width - 20;
            DrawSquads(R(x, box.y + 11, width, 52));
            int count = 0;
            for (int i = 0; i < G.RosterCount; i++)
                if (G.RosterSquad(i) == G.SelectedSquad) count++;

            float gap = 4;
            float tile = (width - Mathf.Max(0, count - 1) * gap) / Mathf.Max(1, count);
            int n = 0;
            for (int i = 0; i < G.RosterCount; i++)
            {
                if (G.RosterSquad(i) != G.SelectedSquad) continue;
                int soldier = i;
                string label = $"{G.RosterName(i)}\n{G.RosterStatus(i)}";
                if (Button(R(x + n * (tile + gap), box.y + 71, tile, 57), label,
                    enabled: G.RosterAlive(i), selected: G.SelectedSoldier == i, dark: true))
                    Submit(() => G.SelectSoldier(soldier));
                n++;
            }

            int selected = G.SelectedSoldier;
            bool ready = selected >= 0 && selected < G.RosterCount &&
                G.RosterSquad(selected) == G.SelectedSquad && G.RosterAlive(selected);
            string possess = ready ? G.RosterName(selected) + "を直接操作" : "隊員を選ぶ";
            if (Button(R(x, box.y + 141, width, 57), possess, enabled: ready, dark: true))
                Submit(() => G.Possess(selected));
        }

        void DrawSquads(Rect box, bool atAim = false)
        {
            int count = 0;
            for (int squad = 0; squad < 3; squad++)
                if (HasSquad(squad)) count++;
            float width = (box.width - Mathf.Max(0, count - 1) * 4) / Mathf.Max(1, count);

            int n = 0;
            for (int i = 0; i < 3; i++)
            {
                if (!HasSquad(i)) continue;
                int squad = i;
                if (Button(R(box.x + n * (width + 4), box.y, width, box.height),
                    G.SquadName(i), selected: !atAim && G.SelectedSquad == i, dark: true))
                {
                    if (atAim) Submit(() => G.OrderAtAim(squad));
                    else Submit(() => G.SelectSquad(squad));
                }
                n++;
            }
        }

        bool HasSquad(int squad)
        {
            for (int i = 0; i < G.RosterCount; i++)
                if (G.RosterSquad(i) == squad) return true;
            return false;
        }

        void DrawOrders(Rect box)
        {
            Instrument(box);
            float x = box.x + 10, width = box.width - 20, half = (width - 6) / 2;
            if (G.EditingWaypoints) { DrawWaypointEditor(box,x,width,half); return; }
            if (orderPickerOpen)
            {
                DrawOrderPicker(box, x, width, half);
                return;
            }

            Text(R(x, box.y + 5, width, 25), $"{G.SquadName(G.SelectedSquad)}への指示", 16, Mist, true);
            string activeOrder = G.SquadOrderName(G.SelectedSquad);
            Text(R(x, box.y + 31, width, 25), $"実行中 {activeOrder}    次の命令 {G.CurrentOrder}", BodySize, Amber, true);
            if (Button(R(x, box.y + 66, half, 48), "任務地点へ", dark: true)) Submit(G.OrderAtObjective);
            if (Button(R(x + half + 6, box.y + 66, half, 48), "補給へ", dark: true)) Submit(G.OrderAtSupply);
            if (Button(R(x, box.y + 119, half, 48), "次の命令を選ぶ", dark: true))
                orderPickerOpen = true;
            if (Button(R(x + half + 6, box.y + 119, half, 48), "設備・資材", dark: true))
                fieldPanel = true;
        }

        void DrawOrderPicker(Rect box, float x, float width, float half)
        {
            if(Button(R(x+half+6,box.y+4,half,48), "経路を描く", dark:true)) { orderPickerOpen=false; Submit(G.BeginWaypointEdit); }
            Text(R(x, box.y + 5, half, 25), "次の命令を選ぶ", 18, Cream, true);
            Text(R(x, box.y + 29, width, 23), "地図で地点を指定", 15, Mist);
            for (int i = 0; i < FieldOrders.Length; i++)
            {
                int order = i;
                Rect choice = R(x + (i % 2) * (half + 6), box.y + 61 + (i / 2) * 53, half, 48);
                string label = FieldOrders[i];
                if (Button(choice, label, selected: label == G.CurrentOrder, dark: true))
                {
                    Submit(() => G.SelectOrder(order));
                    orderPickerOpen = false;
                }
            }

            if (Button(R(x + half + 6, box.y + 167, half, 48), "戻る", dark: true))
                orderPickerOpen = false;
        }

        void DrawFacilities()
        {
            ModalBackdrop();
            Rect box = Dialog(612, 470);
            float x = box.x + 22, width = box.width - 44;
            Text(R(x, box.y + 12, width, 43), "設備・資材", 27, Cream, true);
            Text(R(x, box.y + 62, width, 26),
                $"資材　{G.Supply}　　搬入済み　{G.StockDelivered}　　修理　{G.Repair01:0%}", BodySize, Mist);

            float column = width / 3;
            Text(R(x, box.y + 91, column, 26), $"弾薬 {G.DepotRounds}発", BodySize, Mist);
            Text(R(x + column, box.y + 91, column, 26), $"医薬品 {G.MedicalSupplies}", BodySize, Mist);
            Text(R(x + column * 2, box.y + 91, column, 26), $"応援 {G.VolunteerCount}人", BodySize, Mist);
            if (G.CircuitCount > 0)
            {
                Text(R(x, box.y + 123, width, 30),
                    $"水位　{G.Water01:0%}　　通路　{(G.PassageOpen ? "通行可" : "閉鎖")}", BodySize,
                    G.PassageOpen ? Green : Amber);
                float tile = (width - (G.CircuitCount - 1) * 6) / G.CircuitCount;
                for (int i = 0; i < G.CircuitCount; i++)
                {
                    int circuit = i;
                    bool on = G.CircuitOn(i);
                    if (Button(R(x + i * (tile + 6), box.y + 157, tile, 53),
                        $"{G.CircuitName(i)}　{(on ? "稼働" : "停止")}", selected: on, dark: true))
                        Submit(() => G.ToggleCircuit(circuit));
                }
            }

            float half = (width - 8) / 2;
            string buildStatus = !HasSquad(2) ? "建設には整備班が必要です" : !G.CanBuild ?
                "建設用地は使用中です" : "建設に必要な資材　4";
            Text(R(x, box.y + 219, width, 28), buildStatus, 16, Mist);
            bool canBuild = HasSquad(2) && G.CanBuild && G.Supply >= 4;
            if (Button(R(x, box.y + 252, half, 52), "救護所を建てる", enabled: canBuild, dark: true))
                Submit(G.BuildClinic);
            if (Button(R(x + half + 8, box.y + 252, half, 52), "修理場を建てる", enabled: canBuild, dark: true))
                Submit(G.BuildWorkshop);
            Text(R(x, box.y + 313, width, 28), G.AlarmHint, 16, Amber, true);
            bool dispatched = G.AlarmActorId >= 0;
            string assignment = dispatched ? "担当を呼び戻す" : G.SquadName(G.SelectedSquad)+"を"+G.AlarmName+"へ";
            bool available = dispatched || G.AlarmActiveRemaining<=0 && G.AlarmCooldownRemaining<=0;
            if(Button(R(x,box.y+346,width,49),assignment,enabled:available,dark:true))
            {
                if(dispatched)Submit(G.CancelAlarmDispatch); else Submit(G.DispatchAlarm);
            }
            Paragraph(R(x, box.y + 404, width - 112, 48), G.Radio, 15, Mist);
            if (Button(R(box.xMax - 119, box.y + 404, 97, 48), "閉じる", true)) fieldPanel = false;
        }

        void DrawDirect()
        {
            DrawBoard();
            DrawQuestDirect();
            int pushed=G.PushedColumn;
            if(pushed>=0)
            {
                DrawStretcherControls(pushed);
                return;
            }
            if (G.TouchUI)
                DrawTouchDirect();
            else
                DrawDesktopDirect();
        }

        void DrawStretcherControls(int column)
        {
            Unit person=Field.Find(Field.ColumnCarriedId(column));
            if(person==null)return;
            float width=G.TouchUI?271:242;
            float panelHeight=G.TouchUI?84:91;
            var panel=R(w-width-14,G.TouchUI?BoardHeight+21:h-232,width,panelHeight);
            Instrument(panel);
            Fill(R(panel.x,panel.y,4,panel.height),Green);
            float x=panel.x+11;
            Text(R(x,panel.y+3,width-20,22),"担架搬送　／　"+G.SoldierName,15,Mist,true);
            Text(R(x,panel.y+23,width-20,28),person.name,21,Cream,true);
            string stop=Field.ColumnNextStop(column);
            var pawn=Field.Controlled;
            int distance=Mathf.RoundToInt(Vector3.Distance(pawn.pos,Field.ColumnDestination(column)));
            Text(R(x,panel.y+51,width-20,29),stop+"　"+distance+" m",17,Amber,true);
            float y=h-69;
            if(Button(R(w-width-14,y-51,width,46),"担架の引き継ぎ",primary:true))
                Submit(()=>OpenColumn(column));
            if(Button(R(w-width-14,y,width,50),"指揮に戻る",dark:true))Submit(G.CommandMode);
        }

        void DrawDesktopDirect()
        {
            if (Button(R(14, h - 56, 96, 42), "無線", selected: directRadioOpen, dark: true))
                directRadioOpen = !directRadioOpen;
            if (directRadioOpen) DrawRadio(14, h - 63, Mathf.Min(w * .38f, 440), "", G.Radio, true, BoardHeight + 20);
            Rect identity = R(w - 245, h - 149, 231, 135);
            Instrument(identity);
            float x = identity.x + 12, width = identity.width - 24;
            Text(R(x, identity.y + 6, 145, 31), G.SoldierName, 22, Cream, true);
            Text(R(x, identity.y + 7, width, 28), $"{G.Health01:0%}", 17, Cream, false, TextAnchor.MiddleRight);
            Bar(R(x, identity.y + 38, width, 4), G.Health01, G.Health01 < .3f ? Rail : Green);
            Text(R(x, identity.y + 44, 65, 17), "スタミナ", 12, Mist);
            Bar(R(x + 68, identity.y + 51, width - 68, 4), G.Stamina01, Amber);
            Text(R(x, identity.y + 62, width, 19), "残弾　/　予備弾", 13, Mist);
            Text(R(x, identity.y + 78, width, 32), $"{G.Ammo:00}  /  {G.Reserve:00}", 27, Amber, true);
            Text(R(x, identity.y + 111, width, 19), $"{Key(ControlAction.Reload)} 装填　F3 灯　{Key(ControlAction.SwitchView)} 指揮", 14, Mist);

            if (!string.IsNullOrEmpty(G.ContextAction))
            {
                Rect prompt = R((w - 346) / 2, h * .61f, 346, 45);
                Panel(prompt, Case, Edge);
                string label = $"{Key(ControlAction.FieldAction)}　{G.ContextAction}";
                Text(prompt, label, FieldLineSize(label, prompt.width - 12, G.LargeText ? 22 : 19, true),
                    Cream, true, TextAnchor.MiddleCenter);
            }

            if (GuideVisible)
            {
                Rect info = R(14, BoardHeight + 20, 387, 114);
                Panel(info, Case, Edge);
                Text(R(26, info.y + 3, 363, 24), $"{MovementKeys} 移動　Shift 走る　左ボタン 射撃", 15, Cream);
                Text(R(26, info.y + 27, 363, 24), $"{Key(ControlAction.Dodge)} 回避／低い柵を越える　右ボタン 照準", 15, Cream);
                Text(R(26, info.y + 54, 363, 24), "F2 作戦手帳　F3 班装備　数字で照準先を指示", 15, Amber, true);
                string commandKeys = "";
                for (int i = 0; i < 3; i++)
                    if (HasSquad(i)) commandKeys += $"{i + 1} {G.SquadName(i)}　";
                Text(R(26, info.y + 80, 363, 24), commandKeys.TrimEnd(), 16, Cream);
            }
        }

        void DrawTouchDirect()
        {
            float equipmentY = BoardHeight + 21;
            Rect identity = R(14, equipmentY, 208, 64);
            Instrument(identity);
            Text(R(25,equipmentY+3,185,23),G.SoldierName+"　"+G.Health01.ToString("0%"),18,Cream,true);
            Bar(R(25,equipmentY+29,184,5),G.Health01,G.Health01<.3f?Rail:Green);
            Text(R(25,equipmentY+37,69,22),"スタミナ",14,Mist);
            Bar(R(91,equipmentY+45,118,4),G.Stamina01,Amber);
            Rect ammo=R(w-191,equipmentY,177,53);
            Instrument(ammo);
            Text(R(ammo.x+9,ammo.y+3,158,17),"残弾 ／ 予備弾",13,Mist);
            Text(R(ammo.x+9,ammo.y+19,158,31),G.Ammo.ToString("00")+" ／ "+G.Reserve.ToString("00"),22,Amber,true);
            if (Button(R(14, equipmentY + 71, 142, 48), "装備・無線", selected: directRadioOpen, dark: true))
                directRadioOpen = !directRadioOpen;
            if (directRadioOpen)
            {
                Rect tools = R(14, equipmentY + 125, 278, 125);
                Instrument(tools);
                Text(R(tools.x + 8, tools.y + 4, tools.width - 16, 23), "照準先に班を派遣", 16, Mist);
                DrawSquads(R(tools.x + 7, tools.y + 30, tools.width - 14, 44), atAim: true);
                if (Button(R(tools.x + 7, tools.y + 79, tools.width - 14, 40), G.LampName + "　" + G.LampCost,
                    enabled: G.LampAvailable, dark: true))
                    Submit(G.UseLamp);
            }
            float actionY = h - 73;
            float actionX = w - 170;
            if (!string.IsNullOrEmpty(G.ContextAction))
            {
                float width = Mathf.Clamp(G.ContextAction.Length * (G.LargeText ? 19 : 17) + 16, 158, 304);
                if (Button(R(actionX - width - 8, actionY, width, 59), G.ContextAction, true))
                    Submit(G.TryAction);
            }
            if (Button(R(actionX, actionY, 156, 59), "指揮に戻る", dark: true)) Submit(G.CommandMode);
            FireBlock fireBlock = Field.FieldFireBlock;
            bool canAim = fireBlock is FireBlock.None or FireBlock.Cooldown or FireBlock.Empty or FireBlock.NoReserve;
            if (Button(R(w - 295, equipmentY + 63, 87, 51), "照準", enabled: canAim, selected: G.Aiming, dark: true))
                Submit(G.ToggleTouchAim);
            if (Button(R(w - 202, equipmentY + 63, 92, 51), "緊急回避", dark: true))
                Submit(G.DodgeTouch);
            string reloadLabel = fireBlock == FireBlock.Reloading ? "装填中" : G.Reserve > 0 ? "装填" : "予備弾なし";
            if (Button(R(w - 104, equipmentY + 63, 90, 51), reloadLabel, enabled: Field.CanReloadField, dark: true))
                Submit(G.Reload);
            if (GuideVisible) DrawRadio(236, equipmentY + 45, w - 546, "", G.Radio, false, equipmentY);
        }

        void DrawAmmo(Rect box)
        {
            Panel(box, Case, Edge);
            Text(R(box.x + 12, box.y + 6, box.width - 24, 23), "残弾　/　予備弾", 15, Mist, true);
            Text(R(box.x + 12, box.y + 27, box.width - 24, 43), $"{G.Ammo:00}  /  {G.Reserve:00}", 30,
                G.Ammo == 0 ? Cream : Amber, true);
        }

        void DrawRadio(float x, float bottom, float width, string objective, string message, bool interactive, float top = 0)
        {
            if(!string.IsNullOrEmpty(message))message=G.RadioSpeaker+"　"+message;
            int radioSize = G.LargeText ? 18 : 15;
            float objectiveHeight = ParagraphHeight(objective, BodySize, width - 20);
            float messageHeight = ParagraphHeight(message, radioSize, width - 32);
            if (objectiveHeight <= 0 && messageHeight <= 0) return;

            float gap = objectiveHeight > 0 && messageHeight > 0 ? 8 : 0;
            float height = objectiveHeight + messageHeight + gap + 18;
            Rect box = R(x, Mathf.Max(top, bottom - height), width, height);
            Panel(box, Case, Edge, interactive);
            float y = box.y + 9;
            if (objectiveHeight > 0)
            {
                Paragraph(R(x + 10, y, width - 20, objectiveHeight), objective, BodySize, Cream);
                y += objectiveHeight + gap;
            }
            if (messageHeight > 0)
            {
                Fill(R(x + 10, y + 5, 5, 10), Amber);
                Paragraph(R(x + 22, y, width - 32, messageHeight), message, radioSize, Mist);
            }
        }
    }
}
