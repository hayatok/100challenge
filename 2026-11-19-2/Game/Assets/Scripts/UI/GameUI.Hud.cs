using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        static readonly string[] FieldOrders = { "移動", "警戒", "誘導", "整備", "補給" };

        int BodySize => G.LargeText ? 20 : 17;

        bool GuideVisible => Time.unscaledTime < guideUntil;
        void ToggleGuide() => guideUntil = GuideVisible ? 0 : float.PositiveInfinity;

        static string Key(ControlAction action) => ControlPreferences.KeyLabel(action);
        static string MovementKeys => Key(ControlAction.Forward)+Key(ControlAction.StrafeLeft)+Key(ControlAction.Backward)+Key(ControlAction.StrafeRight);
        float BoardHeight => G.TouchUI ? 88 : 76;

        void DrawBoard()
        {
            float height = BoardHeight;
            float missionWidth = G.TouchUI ? Mathf.Min(w * .41f, 465) : 336;
            Rect mission = R(14, 12, missionWidth, height);
            Instrument(mission);
            Fill(R(mission.x, mission.y, 4, mission.height), Rail);
            string district = G.DistrictName(G.MissionIndex);
            string banner = G.IsDuty ? $"{district}　救援当直 {G.DutyIndex + 1:00}号" :
                $"{district}　{G.MissionIndex + 1:00}号作戦";
            Text(R(26, 17, mission.width - 24, 22), banner, 14, Mist);
            Text(R(26, 38, mission.width - 24, G.TouchUI ? 41 : 28),
                FieldName, G.TouchUI ? 27 : 22, Cream, true);
            if (G.SectorCount > 0)
            {
                string sector = $"{G.SectorNumber}/{G.SectorCount}　{G.SectorName}";
                if (G.SectorGoal > 0) sector += $"　目標 {G.SectorGoal}人";
                Text(R(26, mission.yMax - 23, mission.width - 24, 19), sector, 14, Amber, true);
            }

            float boardWidth = G.TouchUI ? 248 : 256;
            float x = w - boardWidth - 108;
            Rect board = R(x, 12, boardWidth, height);
            Instrument(board);
            Text(R(x + 13, 16, 130, 22), G.IsDuty ? "救出人数" : "乗車人数", 14, Mist, true);
            Text(R(x + 13, 34, 140, 37), $"{G.Saved:00} / {G.Population:00}", G.TouchUI ? 31 : 26, Amber, true);
            Text(R(x + boardWidth - 103, 16, 90, 22), "残り時間", 14, Mist, false, TextAnchor.MiddleRight);
            Text(R(x + boardWidth - 119, 35, 106, 33), Clock(G.Remaining), G.TouchUI ? 27 : 23,
                G.Remaining < 30 ? new Color32(255, 160, 132, 255) : Cream, true, TextAnchor.MiddleRight);
            float total = Mathf.Max(1, G.Population);
            Rect boarding = R(x + 13, board.yMax - 12, boardWidth - 26, 4);
            Bar(boarding, G.Saved / total, Amber);
            float quotaX = boarding.x + boarding.width * Mathf.Clamp01(G.Needed / total);
            Fill(R(quotaX - 1, boarding.y - 2, 2, boarding.height + 4), Cream);
            if (Button(R(w - 96, 12, 82, G.TouchUI ? 57 : 39), "一時停止", dark: true)) Submit(G.Pause);
            if (G.TouchUI)
            {
                Text(R(w - 96, 73, 82, 24), G.Mode == "FPS" ? "直接操作" : "部隊指揮", 15, Cream,
                    true, TextAnchor.MiddleCenter);
            }
            else if (G.Mode == "FPS")
            {
                Text(R(w - 96, 55, 82, 33), "F1 操作", 15, Cream, true, TextAnchor.MiddleCenter);
            }
            else if (Button(R(w - 96, 55, 82, 33), "F1 操作", selected: GuideVisible, dark: true))
            {
                ToggleGuide();
            }
        }

        void Instrument(Rect box)
        {
            Panel(box, Case, Edge, true);
            Fill(R(box.x + 1, box.y + 1, box.width - 2, 2), new Color32(50, 60, 57, 255));
            Fill(R(box.x + 5, box.yMax - 7, 3, 3), Edge);
            Fill(R(box.xMax - 8, box.yMax - 7, 3, 3), Edge);
        }

        void DrawCommand()
        {
            if (requestOpen && !G.IsDuty) { DrawRequest(); return; }
            if (fieldPanel) { DrawFacilities(); return; }
            DrawBoard();
            if (!G.IsDuty && Button(R(w-164,BoardHeight+18,150,G.TouchUI?48:35),"現場からの要請",dark:true))
                requestOpen=true;
            float rosterWidth = Mathf.Min(w * .32f, G.TouchUI ? 340 : 326);
            float fieldWidth = Mathf.Min(w * .35f, G.TouchUI ? 376 : 346);
            Rect roster = R(14, h - 224, rosterWidth, 210);
            Rect orders = R(w - fieldWidth - 14, h - 242, fieldWidth, 228);

            if (!G.TouchUI || !rosterFolded) DrawRoster(roster);
            if (!G.TouchUI || !ordersFolded) DrawOrders(orders);
            if (G.TouchUI)
            {
                if (rosterFolded)
                {
                    if (Button(R(roster.x, h - 74, roster.width, 60), $"名簿　{G.SquadName(G.SelectedSquad)}", dark: true))
                        rosterFolded = false;
                }
                else if (Button(R(roster.xMax + 5, roster.y, 60, 56), "畳む", dark: true))
                    rosterFolded = true;

                if (ordersFolded)
                {
                    if (Button(R(orders.x, h - 74, orders.width, 60), "班への命令", dark: true))
                        ordersFolded = false;
                }
                else if (Button(R(orders.x - 65, orders.y, 60, 56), "畳む", dark: true))
                    ordersFolded = true;
            }

            DrawCommandRadio(roster, orders);

            if (GuideVisible)
            {
                string mapControls = G.TouchUI ? "タップで地点を指示　ドラッグで地図移動" :
                    $"{MovementKeys}　地図移動　　右クリック　地点を指示　　{Key(ControlAction.SwitchView)}　直接操作";
                Rect mapGuide = R(14, BoardHeight + 19, G.TouchUI ? 345 : 508, 29);
                Fill(mapGuide, Case);
                Text(R(mapGuide.x + 9, mapGuide.y, mapGuide.width - 18, 29), mapControls, 15, Cream, true);
            }
        }

        void DrawCommandRadio(Rect roster, Rect orders)
        {
            float left = roster.xMax + 12;
            float right = orders.x - 12;
            float bottom = h - 14;
            if (G.TouchUI)
            {
                bottom = h - 84;
                left = rosterFolded ? 14 : roster.xMax + 76;
                right = ordersFolded ? w - 14 : orders.x - 76;
                if (!rosterFolded && !ordersFolded)
                {
                    left = 14;
                    right = w - 14;
                    bottom = Mathf.Min(roster.y, orders.y) - 10;
                }
            }
            DrawRadio(left, bottom, right - left, G.Objective, G.Radio, true);
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
            if (Button(R(x, box.y + 141, width, 57), possess, true, ready))
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
            if (orderPickerOpen)
            {
                DrawOrderPicker(box, x, width, half);
                return;
            }

            Text(R(x, box.y + 5, width, 25), $"{G.SquadName(G.SelectedSquad)}への指示", 16, Mist, true);
            string activeOrder = G.SquadOrderName(G.SelectedSquad);
            Text(R(x, box.y + 31, width, 25), $"実行中 {activeOrder}    次の命令 {G.CurrentOrder}", BodySize, Amber, true);
            if (Button(R(x, box.y + 66, half, 48), "任務地点へ", true)) Submit(G.OrderAtObjective);
            if (Button(R(x + half + 6, box.y + 66, half, 48), "補給へ", dark: true)) Submit(G.OrderAtSupply);
            if (Button(R(x, box.y + 119, half, 48), "次の命令を選ぶ", dark: true))
                orderPickerOpen = true;
            if (Button(R(x + half + 6, box.y + 119, half, 48), "設備・資材", dark: true))
                fieldPanel = true;
            string departure = G.CanDepart ? "出発を指示" : G.Saved < G.Needed ?
                $"必要な乗車人数　{G.Saved} / {G.Needed}人" : "出発には作戦目標の達成が必要";
            if (G.IsDuty && !G.CanDepart && (G.SectorGoal == 0 || G.Saved >= G.Needed))
                departure = "現場の作業を続ける";
            if (Button(R(x, box.y + 172, width, 46), departure, G.CanDepart, G.CanDepart, dark: !G.CanDepart))
                Submit(G.Depart);
        }

        void DrawOrderPicker(Rect box, float x, float width, float half)
        {
            Text(R(x, box.y + 5, width, 25), "次の命令を選ぶ", 18, Cream, true);
            Text(R(x, box.y + 29, width, 23), "地図で地点を指定すると発令します", 15, Mist);
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
            if (G.TouchUI)
                DrawTouchDirect();
            else
                DrawDesktopDirect();
        }

        void DrawDesktopDirect()
        {
            DrawRadio(14, h - 14, Mathf.Min(w * .41f, 510), G.Objective, G.Radio, false);
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
            Text(R(x, identity.y + 111, width, 19), $"{Key(ControlAction.Reload)}  装填　　{Key(ControlAction.SwitchView)}  指揮", 14, Mist);

            if (!string.IsNullOrEmpty(G.ContextAction))
            {
                Rect prompt = R((w - 250) / 2, h * .61f, 250, 42);
                Panel(prompt, Case, Edge);
                Text(prompt, $"{Key(ControlAction.FieldAction)}　{G.ContextAction}", 19, Cream, true, TextAnchor.MiddleCenter);
            }

            if (GuideVisible)
            {
                Rect info = R(14, BoardHeight + 20, 387, 114);
                Panel(info, Case, Edge);
                Text(R(26, info.y + 3, 363, 24), $"{MovementKeys} 移動　Shift 走る　左ボタン 射撃", 15, Cream);
                Text(R(26, info.y + 27, 363, 24), $"{Key(ControlAction.Dodge)} 緊急回避　右ボタン 照準", 15, Cream);
                Text(R(26, info.y + 54, 363, 24), "照準先を指示", 15, Amber, true);
                string commandKeys = "";
                for (int i = 0; i < 3; i++)
                    if (HasSquad(i)) commandKeys += $"{i + 1} {G.SquadName(i)}　";
                Text(R(26, info.y + 80, 363, 24), commandKeys.TrimEnd(), 16, Cream);
            }
        }

        void DrawTouchDirect()
        {
            Rect identity = R(14, 109, 230, 84);
            Instrument(identity);
            Text(R(26, 112, 206, 19), "隊員識別票", 15, Mist);
            Text(R(26, 131, 206, 26), G.SoldierName, 24, Cream, true);
            Text(R(26, 159, 99, 20), $"体力 {G.Health01:0%}", 14, Cream);
            Text(R(133, 159, 99, 20), "スタミナ", 14, Mist);
            Bar(R(26, 182, 99, 4), G.Health01, G.Health01 < .3f ? Rail : Green);
            Bar(R(133, 182, 99, 4), G.Stamina01, Amber);
            DrawAmmo(R(w - 204, 106, 190, 78));
            Text(R(14, 194, 268, 26), "照準先を指示", 16, Cream, true);
            DrawSquads(R(14, 218, 264, 56), atAim: true);
            float actionY = h - 73;
            float actionX = w - 170;
            if (!string.IsNullOrEmpty(G.ContextAction) && Button(R(actionX - 166, actionY, 158, 59), G.ContextAction, true))
                Submit(G.TryAction);
            if (Button(R(actionX, actionY, 156, 59), "指揮に戻る", dark: true)) Submit(G.CommandMode);
            if (Button(R(w - 295, 193, 87, 55), "照準", selected:G.Aiming, dark:true))
                Submit(G.ToggleTouchAim);
            if (Button(R(w - 202, 193, 92, 55), "緊急回避", dark: true))
                Submit(G.DodgeTouch);
            if (Button(R(w - 104, 193, 90, 55), G.Reserve > 0 ? "装填" : "予備弾なし", enabled: G.Reserve > 0, dark: true))
                Submit(G.Reload);
            DrawRadio(256, 187, w - 472, "", G.Radio, true);
            if (G.IsDuty) DrawRadio(246, h - 14, w - 588, G.Objective, "", false);
        }

        void DrawAmmo(Rect box)
        {
            Panel(box, Case, Edge);
            Text(R(box.x + 12, box.y + 6, box.width - 24, 23), "残弾　/　予備弾", 15, Mist, true);
            Text(R(box.x + 12, box.y + 27, box.width - 24, 43), $"{G.Ammo:00}  /  {G.Reserve:00}", 30,
                G.Ammo == 0 ? Cream : Amber, true);
        }

        void DrawRadio(float x, float bottom, float width, string objective, string message, bool interactive)
        {
            if(!string.IsNullOrEmpty(message))message=G.RadioSpeaker+"　"+message;
            int radioSize = G.LargeText ? 18 : 15;
            float objectiveHeight = ParagraphHeight(objective, BodySize, width - 20);
            float messageHeight = ParagraphHeight(message, radioSize, width - 32);
            if (objectiveHeight <= 0 && messageHeight <= 0) return;

            float gap = objectiveHeight > 0 && messageHeight > 0 ? 8 : 0;
            float height = objectiveHeight + messageHeight + gap + 18;
            Rect box = R(x, bottom - height, width, height);
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
