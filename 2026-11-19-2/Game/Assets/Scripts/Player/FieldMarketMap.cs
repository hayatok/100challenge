using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        Vector3[][] marketPaths;

        int marketGatePawn = -1;

        internal Vector3[][] MarketPaths()
        {
            if (marketPaths == null) marketPaths = new Vector3[2][];
            marketPaths[0] = sim.MarketRoutePoints(0);
            marketPaths[1] = sim.MarketRoutePoints(1);
            return marketPaths;
        }

        internal void FrameMarketRoutes(Rect viewport)
        {
            var paths = MarketPaths();
            mapYaw = -19;
            var turn = Quaternion.Euler(0, mapYaw, 0);
            var across = turn * Vector3.right;
            var forward = turn * Vector3.forward;
            float tilt = Mathf.Sin(51 * Mathf.Deg2Rad);
            var limits = new Bounds();
            bool first = true;
            foreach (var path in paths)
                foreach (var p in path)
                {
                    var projected = new Vector3(Vector3.Dot(p, across), Vector3.Dot(p, forward) * tilt, 0);
                    if (first) { limits = new Bounds(projected, Vector3.zero); first = false; }
                    else limits.Encapsulate(projected);
                }
            if (first) return;
            zoom = Mathf.Clamp(Mathf.Max((limits.size.x + 4) / (2 * eye.aspect * viewport.width),
                (limits.size.y + 4) / (2 * viewport.height)), 8, 50);
            var middle = limits.center;
            middle.x += (.5f - viewport.center.x) * 2 * zoom * eye.aspect;
            middle.y += (.5f - viewport.center.y) * 2 * zoom;
            mapCenter = across * middle.x + forward * (middle.y / tilt);
            followedColumn = 0;
            FrameCamera(0, true);
        }

        internal Vector3 MarketScreenPoint(Vector3 p) => eye.WorldToScreenPoint(p);

        internal void PossessMarketOpener(int id)
        {
            PossessFieldActor(id);
            if (sim.Controlled?.id == id) marketGatePawn = id;
        }

        bool CanOpenLocalMarketGate
        {
            get
            {
                if (missionIndex != 0 || IsDuty || sim.Controlled == null || !sim.ColumnsActive ||
                    !sim.CanCommandColumn(0, 4, SelectedSquad)) return false;
                // At the latch the player's hands can still reach it with the head turned.
                var toGate = MarketPassage.Gate - sim.Controlled.pos;
                return toGate.sqrMagnitude < 1.2f ||
                    Vector3.Dot(Quaternion.Euler(0, sim.Controlled.yaw, 0) * Vector3.forward, toGate.normalized) >= .30f;
            }
        }

        bool HeadingForMarketGate => marketGatePawn >= 0 && sim.Controlled?.id == marketGatePawn &&
            missionIndex == 0 && sim.ColumnsActive && !sim.ColumnsComplete && !sim.ColumnControlOpen(0);

        void DrawMarketGateBearing()
        {
            var target = MarketPassage.Gate + Vector3.up * 1.45f;
            Vector3 delta = target - sim.Controlled.pos;
            var view = eye.WorldToViewportPoint(target);
            string text = "市場横戸　" + Mathf.RoundToInt(new Vector2(delta.x, delta.z).magnitude) + " m";
            Color tint = new Color(.62f, .94f, .82f);
            if (view.z > 0 && view.x >= .16f && view.x <= .84f && view.y >= .24f && view.y <= .75f)
            {
                WorldTag(target, text, tint, true);
                return;
            }
            float bearing = Mathf.DeltaAngle(sim.Controlled.yaw, Mathf.Atan2(delta.x, delta.z) * Mathf.Rad2Deg);
            string side = Mathf.Abs(bearing) > 145 ? "後方" : Mathf.Abs(bearing)<12 ? "正面" : bearing < 0 ? "左手" : "右手";
            float height = Mathf.Clamp(Screen.height * .045f, 20, 36);
            var box = new Rect((Screen.width - height * 8.5f) * .5f, Screen.height * .31f, height * 8.5f, height);
            Box(box.x, box.y, box.width, box.height, new Color(.055f, .09f, .08f, .88f));
            worldText.fontSize = Mathf.RoundToInt(height * .65f);
            worldText.normal.textColor = tint;
            GUI.Label(box, side + "　" + text, worldText);
        }
    }
}
