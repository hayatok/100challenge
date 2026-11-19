using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        readonly List<Rect> marketLabels = new List<Rect>(6);
        bool marketLedger;
        Vector2 marketFrameSize;
        static readonly Color StreetInk = new Color32(255, 207, 114, 255);
        static readonly Color AwningInk = new Color32(133, 233, 203, 255);
        static readonly Color RouteShadow = new Color32(20, 33, 32, 227);

        void DrawMarketMap()
        {
            float width = Mathf.Min(292, w * .31f);
            float x = w - width - 12;
            Rect sheet = R(x, 10, width, h - 20);
            Rect field = R(13, 64, x - 26, h - 80);
            if (marketFrameSize != new Vector2(w, h))
            {
                var vp = new Rect((safeArea.x + field.x * scale) / Screen.width,
                    (safeArea.yMax - field.yMax * scale) / Screen.height,
                    field.width * scale / Screen.width, field.height * scale / Screen.height);
                G.FrameMarketRoutes(vp);
                marketFrameSize = new Vector2(w, h);
            }

            DrawMarketTraces(field);
            var header = R(13, 12, Mathf.Min(300, field.width), 43);
            Instrument(header);
            Fill(R(header.x, header.y, 4, header.height), Rail);
            Text(R(header.x + 12, header.y, header.width - 24, header.height),
                "朝市　青果店からバス停へ", 22, Cream, true);
            Instrument(sheet);
            float col = x + 11, cw = width - 22, y = sheet.y + 9;
            Text(R(col, y, cw - 65, 39), "避難隊列", 24, Cream, true);
            if (Button(R(col + cw - 70, y, 70, 41), "閉じる", dark:true))
                Submit(() => { CloseFieldOverlay(); G.LocateColumn(0); });

            y += 48;
            Text(R(col, y, cw, 22), "付添班", 15, Mist, true);
            y += 24;
            DrawSquads(R(col, y, cw, 44));
            y += 51;
            for (int route = 0; route < 2; route++)
            {
                int command = route;
                bool selected = Field.ColumnRoute(0) == route && !Field.ColumnHeld(0);
                Rect button = R(col, y, cw, 45);
                if (Button(button, Field.ColumnActionLabel(0, route), selected:selected,
                    enabled:Field.CanCommandColumn(0, route, G.SelectedSquad), dark:true))
                    Submit(() => G.ColumnAction(0, command));
                Color ink = route == 0 ? StreetInk : AwningInk;
                Fill(R(col + 7, y + 12, 4, route == 0 ? 20 : 8), ink);
                if (route == 1) Fill(R(col + 7, y + 24, 4, 8), ink);
                y += 50;
            }

            var leader = Field.Find(Field.ColumnLeaderId(0));
            var prospective = Field.Find(Field.MarketGateCrew(G.SelectedSquad));
            var assigned = Field.Find(Field.ColumnOperatorId(0));
            bool opened = Field.ColumnControlOpen(0);
            string gate = opened ? (Field.MarketGateLift < .82f ? "横戸　開放中" : "横戸　開通") :
                assigned == null ? "横戸　閉鎖中" : assigned.name + "が横戸へ移動中";
            Text(R(col, y, cw, 23), gate, 17, opened ? AwningInk : Cream, true);
            y += 26;
            bool fresh = Field.ColumnRoute(0) < 0;
            if (!opened)
            {
                if (fresh)
                {
                    if (Button(R(col, y, cw, 49), "横戸で待ち合わせ", primary:true,
                        enabled:Field.CanMeetAtMarketGate(G.SelectedSquad)))
                        Submit(() => { CloseFieldOverlay(); G.MeetAtMarketGate(); });
                }
                else
                {
                    DrawMarketGateOrders(col, y, cw, prospective);
                }
                y += 54;
            }

            bool held = Field.ColumnHeld(0);
            Text(R(col, y, cw, 24), fresh && !opened ? "付添を班に任せ、自分で横戸を開ける" : Field.ColumnStatus(0), 15, Mist);
            y += 27;
            float split = (cw - 4) * .53f;
            if (fresh && !opened) DrawMarketGateOrders(col, y, cw, prospective);
            else
            {
                if (leader != null) ColumnStaff(R(col, y, split, 44), leader, "先導");
                else Text(R(col, y, split, 44), "先導役は未配置", 15, Mist);
                DrawColumnAction(0, held ? 3 : 2, R(col + split + 4, y, cw - split - 4, 44));
            }
            if (Button(R(col, sheet.yMax - 52, cw, 43), "店主の名簿", dark:true))
                marketLedger = true;
        }

        void DrawMarketGateOrders(float x, float y, float width, Unit opener)
        {
            float half = (width - 4) * .5f;
            if (Field.MarketMeeting)
            {
                if (Button(R(x, y, half, 44), "待ち合わせを解く", dark:true))
                    Submit(Field.CancelMarketMeeting);
            }
            else if (Button(R(x, y, half, 44), "横戸を開ける", dark:true,
                enabled:Field.CanCommandColumn(0, 4, G.SelectedSquad)))
                Submit(() => G.ColumnAction(0, 4));

            if (Button(R(x + half + 4, y, half, 44), opener == null ? "担当不在" : opener.name + "で横戸へ",
                dark:true, enabled:opener != null))
                Submit(() => { CloseFieldOverlay(); G.PossessMarketOpener(opener.id); });
        }

        Vector2 MarketMapPoint(Vector3 world) => ToLogical(G.MarketScreenPoint(world));
        static bool InMarketView(Rect area, Vector2 p) => area.Contains(p);

        void DrawMarketTraces(Rect area)
        {
            marketLabels.Clear();
            var paths = G.MarketPaths();
            for (int route = 0; route < paths.Length; route++)
            {
                var path = paths[route];
                Color ink = route == 0 ? StreetInk : AwningInk;
                for (int i = 1; i < path.Length; i++)
                {
                    Vector2 a = MarketMapPoint(path[i-1] + Vector3.up * .16f);
                    Vector2 b = MarketMapPoint(path[i] + Vector3.up * .16f);
                    if (!InMarketView(area, a) || !InMarketView(area, b)) continue;
                    DrawMarketLine(a, b, ink, route == 1);
                    if (route == 1 && Field.MarketMeeting && Field.MarketGateLift < .82f &&
                        (path[i] - Field.MarketMeetingPoint).sqrMagnitude < .02f) break;
                }
            }
            // Seen attackers use the same visibility as the regular command map.
            foreach (var unit in Field.Units)
            {
                if (!unit.active || !unit.visible || unit.kind != UnitKind.Infected) continue;
                Vector2 pt = MarketMapPoint(unit.pos + Vector3.up);
                if (!InMarketView(area, pt)) continue;
                var danger = new Color32(255, 124, 100, 255);
                Fill(R(pt.x - 5, pt.y - 4, 10, 3), danger);
                Fill(R(pt.x - 5, pt.y - 1, 3, 4), danger);
                Fill(R(pt.x + 2, pt.y - 1, 3, 4), danger);
            }
            var aPerson = Field.Find(Field.ColumnMemberId(0, 0));
            var bPerson = Field.Find(Field.ColumnMemberId(0, 1));
            for (int i=0; i<2; i++)
            {
                var person = i==0 ? aPerson : bPerson;
                if (person?.active != true) continue;
                var pt = MarketMapPoint(person.pos + Vector3.up * .5f);
                if (!InMarketView(area, pt)) continue;
                Fill(R(pt.x - 5, pt.y - 5, 10, 10), RouteShadow);
                Fill(R(pt.x - 3, pt.y - 3, 6, 6), Paper);
            }
            if (paths[0].Length > 0)
                MapCaption(area, paths[0][paths[0].Length - 1], "バス乗車口", StreetInk, 0, 7);
            MapCaption(area, MarketPassage.Gate, Field.MarketGateLift >= .82f ? "横戸　開" : "横戸　閉", AwningInk, -43, 10);
            if (aPerson?.active == true || bPerson?.active == true)
            {
                bool together = aPerson?.active == true && bPerson?.active == true &&
                    Vector2.Distance(MarketMapPoint(aPerson.pos), MarketMapPoint(bPerson.pos)) < 83;
                if (together) MapCaption(area,(aPerson.pos + bPerson.pos) * .5f,"中野・谷口",Paper,0,-29);
                else
                {
                    if (aPerson?.active == true) MapCaption(area,aPerson.pos,"中野",Paper,0,-28);
                    if (bPerson?.active == true) MapCaption(area,bPerson.pos,"谷口",Paper,0,-28);
                }
            }
            if (Field.MarketMeeting && Field.MarketGateLift < .82f)
                MapCaption(area, Field.MarketMeetingPoint, "待ち合わせ", AwningInk, -60, -24);
            MarketRole(area, Field.ColumnLeaderId(0), "先導", 48);
            MarketRole(area, Field.ColumnOperatorId(0), "解錠", -48);
        }

        void MarketRole(Rect area, int id, string role, float side)
        {
            var actor=Field.Find(id);
            if (actor?.active != true) return;
            MapCaption(area, actor.pos, role+" "+actor.name, Green, side, -30);
        }

        void DrawMarketLine(Vector2 a, Vector2 b, Color tint, bool dashed)
        {
            var delta = b - a;
            float length = delta.magnitude;
            if (length < 1) return;
            Matrix4x4 matrix = GUI.matrix;
            GUI.matrix = matrix * Matrix4x4.TRS(new Vector3(a.x, a.y, 0),
                Quaternion.Euler(0, 0, Mathf.Atan2(delta.y, delta.x) * Mathf.Rad2Deg), Vector3.one);
            if (dashed)
            {
                for (float dx = 0; dx < length; dx += 14)
                {
                    float segment = Mathf.Min(9, length - dx);
                    Fill(R(dx, -3, segment, 6), RouteShadow);
                    Fill(R(dx, -1.5f, segment, 3), tint);
                }
            }
            else
            {
                Fill(R(0, -3, length, 6), RouteShadow);
                Fill(R(0, -1.5f, length, 3), tint);
            }
            GUI.matrix = matrix;
        }

        void MapCaption(Rect area, Vector3 world, string label, Color ink, float offsetX, float offsetY)
        {
            Vector2 p = MarketMapPoint(world + Vector3.up * .48f);
            if (!InMarketView(area,p)) return;
            float width = label.Length * 16 + 16;
            var box = R(Mathf.Clamp(p.x - width * .5f + offsetX, area.x, area.xMax - width),
                Mathf.Clamp(p.y + offsetY, area.y, area.yMax - 24), width, 24);
            float originalY = box.y;
            for (int i=0; i<7; i++)
            {
                bool overlap=false;
                foreach (Rect other in marketLabels) if (other.Overlaps(box)) { overlap=true; break; }
                if (!overlap) break;
                int step=i/2+1;
                box.y=Mathf.Clamp(originalY + ((i%2==0) ? -step : step) * 26, area.y, area.yMax-box.height);
            }
            marketLabels.Add(box);
            Vector2 anchor = new Vector2(Mathf.Clamp(p.x,box.x,box.xMax),Mathf.Clamp(p.y,box.y,box.yMax));
            var d=anchor-p;
            if (d.sqrMagnitude>20)
            {
                var prior=GUI.matrix;
                GUI.matrix=prior*Matrix4x4.TRS(new Vector3(p.x,p.y,0),
                    Quaternion.Euler(0,0,Mathf.Atan2(d.y,d.x)*Mathf.Rad2Deg),Vector3.one);
                Fill(R(0,-1,d.magnitude,2),RouteShadow);
                Fill(R(0,0,d.magnitude,1),ink);
                GUI.matrix=prior;
            }
            Fill(box, RouteShadow);
            Fill(R(box.x, box.y, 3, box.height), ink);
            Text(box, label, 15, ink, true, TextAnchor.MiddleCenter);
        }
    }
}
