using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        const int DutyCount = 4;
        bool dutyMenuOpen, dutyContinueFailed;
        int selectedDuty;

        string FieldName => G.IsDuty ? G.CurrentDutyTitle : G.MissionName(G.MissionIndex);

        void OpenDutyMenu()
        {
            dutyMenuOpen = true;
            dutyContinueFailed = false;
            ResetFocus();
        }

        void CloseDutyMenu()
        {
            dutyMenuOpen = false;
            ResetFocus();
        }

        void DrawDutyBriefing()
        {
            Photo(desk, new Color(0, 0, 0, .35f));
            float leftWidth = Mathf.Clamp(w * .34f, 290, 436);
            Rect list = R(24, 29, leftWidth, h - 56);
            Panel(list, Case, Edge);
            Text(R(38, 36, leftWidth - 28, 41), "救援当直", 24, Cream, true);

            for (int i = 0; i < DutyCount; i++)
            {
                int duty = i;
                string district = G.DistrictName(i * 2);
                string state = G.DutyCompleted(i) ? "完了" : "記録なし";
                if (Button(R(38, 87 + i * 65, leftWidth - 28, 56),
                    $"{i + 1:00} {district}　{state}\n{G.DutyName(i)}", selected: i == selectedDuty, dark: true))
                {
                    selectedDuty = duty;
                    dutyContinueFailed = false;
                }
            }
            int completed = 0;
            for (int i = 0; i < DutyCount; i++)
                if (G.DutyCompleted(i)) completed++;
            Text(R(38, 349, leftWidth - 28, 29), $"完了記録　{completed} / {DutyCount}", 17, Amber, true);
            if (Button(R(38, list.yMax - 66, 145, 54), "タイトルへ", dark: true))
                CloseDutyMenu();

            float paperX = w * .49f;
            Rect paper = R(paperX, 29, w - paperX - 24, h - 56);
            Panel(paper, Paper, Ink);
            Fill(R(paper.x, paper.y, paper.width, 7), Rail);
            float x = paper.x + 20, width = paper.width - 40;
            Text(R(x, 49, width, 23), $"救援当直指示書　{selectedDuty + 1:00}号", 16, Dim, true);
            Text(R(x, 79, width, 45), G.DutyName(selectedDuty), 27, Ink, true);
            Text(R(x, 128, width, 24), G.DistrictName(selectedDuty * 2), 18, Ink);
            Fill(R(x, 155, width, 1), Dim);
            Paragraph(R(x, 172, width, 143), G.DutyBrief(selectedDuty), G.LargeText ? 20 : 17, Ink);

            float y = paper.yMax - 67;
            if (G.HasDutySave && Button(R(x, y - 61, width, 52), "救援当直のつづきから"))
            {
                Submit(() =>
                {
                    G.ContinueDuty();
                    dutyContinueFailed = G.Phase == "Title";
                });
            }

            if (dutyContinueFailed)
                Text(R(x, y - 90, width, 25), "保存した当直を読み込めませんでした", 16, Rail);
            if (Button(R(x, y, width, 53), "この当直を始める", true))
                Submit(() => G.StartDuty(selectedDuty));
        }

        void DrawDutyDebrief()
        {
            Photo(desk, new Color(0, 0, 0, .44f));
            Rect box = R(w * .28f, 25, w * .66f, h - 50);
            Panel(box, Paper, Ink);
            Fill(R(box.x, box.y, box.width, 6), G.Won ? new Color32(41, 96, 62, 255) : Rail);

            float x = box.x + 26, width = box.width - 52;
            Text(R(x, box.y + 18, width, 25), $"救援当直記録　{G.DutyIndex + 1:00}号", 16, Dim, true);
            Text(R(x, box.y + 47, width, 51), G.Won ? "当直完了" : "当直中止", 37, Ink, true);
            Text(R(x, box.y + 104, width, 35), FieldName, 22, Ink);
            Fill(R(x, box.y + 149, width, 1), Dim);
            RecordLine(x, box.y + 158, width, "救出人数", $"{G.Saved} / {G.Population}人");
            RecordLine(x, box.y + 203, width, "当直時間", Clock(G.Elapsed));
            float y = box.yMax - 71;
            if (G.Won)
            {
                Paragraph(R(x, box.y + 264, width, 91), G.CurrentDutyEnding, G.LargeText ? 20 : 17, Ink);
                float half = (width - 8) / 2;
                if (Button(R(x, y, half, 52), "タイトルへ", true)) Submit(G.Home);
                if (Button(R(x + half + 8, y, half, 52), "再挑戦する")) Submit(G.RetryDuty);
                return;
            }

            Text(R(x, box.y + 256, width, 26), "中止理由", 16, Rail, true);
            Paragraph(R(x, box.y + 289, width, 79), G.Objective, G.LargeText ? 20 : 17, Ink);
            float first = width * .37f;
            float second = (width - first - 16) / 2;
            if (Button(R(x, y, first, 52), "直前の記録から", true)) Submit(G.RetryCheckpoint);
            if (Button(R(x + first + 8, y, second, 52), "最初から")) Submit(G.RetryDuty);
            if (Button(R(x + first + second + 16, y, second, 52), "タイトルへ")) Submit(G.Home);
        }
    }
}
