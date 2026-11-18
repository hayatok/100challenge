using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        const int MissionCount = 8;
        static readonly string[] DifficultyNames = { "物語", "標準", "困難" };

        enum SettingsPage { General, Keyboard, Touch }
        static readonly string[] BindingLabels =
        {
            "前進", "後退", "左移動", "右移動", "装填", "緊急回避", "行動", "指揮・直接操作の切り替え"
        };
        static readonly string[] FireHorizontalLabels = { "内側", "標準", "外側" };
        static readonly string[] FireVerticalLabels = { "下", "標準", "上" };
        SettingsPage settingsPage;
        ControlAction? captureAction;
        string bindingStatus;

        void DrawTitle()
        {
            if (dutyMenuOpen) { DrawDutyBriefing(); return; }
            Photo(station, new Color(0, 0, 0, .19f));
            if (settingsOpen) { DrawSettings(() => settingsOpen = false); return; }
            if (creditsOpen) { DrawCredits(() => creditsOpen = false); return; }
            float width = Mathf.Clamp(w * .44f, 390, 530);
            Fill(R(0, 0, width, h), new Color(.055f, .075f, .075f, .96f));
            Fill(R(width - 6, 0, 6, h), Rail);
            Fill(R(32, 48, 52, 4), Amber);
            Text(R(32, 62, width - 64, 26), "災害対策本部　非常輸送", 17, Amber, true);
            Text(R(27, 98, width - 48, 86), "避難指令", 60, Cream, true);
            Text(R(32, continueFailed ? 172 : 178, width - 64, 64), "班を指揮し、隊員として\n住民を避難させる。", 23, Cream, true);

            if (G.CanContinue && Button(R(32, 255, width - 64, 52), "つづきから", true))
                Submit(ContinueMission);
            if (Button(R(32, G.CanContinue ? 313 : 270, width - 64, 52), "作戦を選ぶ", !G.CanContinue))
                Submit(() => G.Brief(Mathf.Clamp(G.Unlocked, 0, MissionCount - 1)));

            bool hasEnding = G.IsMissionComplete(MissionCount - 1);
            float dutyWidth = hasEnding && !continueFailed ? (width - 72) / 2 : width - 64;
            float dutyY = G.CanContinue ? 371 : 332;
            if (Button(R(32, dutyY, dutyWidth, 55), "救援当直", dark: true))
                OpenDutyMenu();
            if (continueFailed)
                Text(R(32, 234, width - 64, 22), "保存した作戦を読み込めませんでした", 16, Amber);
            else if (hasEnding && Button(R(40 + dutyWidth, dutyY, dutyWidth, 55), "最終報告を読む", dark: true))
                Submit(G.ShowEnding);

            if (Button(R(32, 432, (width - 72) / 2, 49), "設定", dark: true))
            {
                settingsOpen = true;
                SetSettingsPage(SettingsPage.General);
            }
            if (Button(R(width / 2 + 4, 432, (width - 72) / 2, 49), "クレジット", dark: true))
            {
                creditsOpen = true;
                ResetFocus();
            }

        }

        void ContinueMission()
        {
            G.Continue();
            continueFailed = G.Phase == "Title";
        }

        void DrawBriefing()
        {
            Photo(desk, new Color(0, 0, 0, .35f));
            float leftWidth = Mathf.Clamp(w * .34f, 290, 436);
            float paperX = w * .49f;
            Rect paper = R(paperX, 29, w - paperX - 24, h - 56);
            Panel(R(24, 29, leftWidth, 442), Case, Edge);
            Text(R(38, 36, leftWidth - 28, 41), "作戦一覧", 24, Cream, true);

            for (int index = 0; index < MissionCount; index++)
            {
                int mission = index;
                float rowY = 84 + index * 40;
                string status = mission > G.Unlocked ? "未解禁" : G.IsMissionComplete(mission) ? "完了" : "";
                string label = $"{mission + 1:00} {G.MissionName(mission)}";
                if (status.Length > 0) label += "  " + status;
                if (Button(R(38, rowY, leftWidth - 28, 37), label,
                    enabled: mission <= G.Unlocked, selected: mission == G.MissionIndex, dark: true))
                    Submit(() => G.Brief(mission));
            }
            if (Button(R(38, 413, 124, 46), "タイトルへ", dark: true)) Submit(G.Home);

            Panel(paper, Paper, Ink);
            Fill(R(paper.x, paper.y, paper.width, 7), Rail);
            Text(R(paper.x + 20, 49, paper.width - 40, 22), $"非常輸送指示書　{G.MissionIndex + 1:00}号", 16, Dim, true);
            Text(R(paper.x + 20, 77, paper.width - 40, 43), G.MissionName(G.MissionIndex), 33, Ink, true);
            Text(R(paper.x + 20, 122, paper.width - 40, 24), G.DistrictName(G.MissionIndex), 18, Ink);
            Fill(R(paper.x + 20, 154, paper.width - 40, 1), Dim);
            Paragraph(R(paper.x + 20, 166, paper.width - 40, 112), G.MissionBrief(G.MissionIndex),
                G.LargeText ? 20 : 17, Ink);
            int best = G.Best(G.MissionIndex);
            if (G.IsMissionComplete(G.MissionIndex))
                Text(R(paper.x + 20, 285, paper.width - 40, 24), $"最多救出　{best}人", 17, Ink, true);

            float actionY = paper.yMax - 70;
            Text(R(paper.x + 20, actionY - 75, paper.width - 40, 24), "難度", 15, Dim, true);
            float difficultyWidth = (paper.width - 52) / 3;
            for (int i = 0; i < DifficultyNames.Length; i++)
            {
                int choice = i;
                if (Button(R(paper.x + 20 + (difficultyWidth + 6) * i, actionY - 48, difficultyWidth, 40),
                    DifficultyNames[i], selected: i == G.DifficultyIndex))
                    Submit(() => G.SetDifficulty(choice));
            }
            if (Button(R(paper.x + 20, actionY, paper.width - 40, 53), "出動する", true)) Submit(G.Deploy);
        }

        void DrawPause()
        {
            ModalBackdrop();
            if (settingsOpen) { DrawSettings(() => settingsOpen = false); return; }
            if (dispatchOpen) { DrawReturnConfirmation(); return; }

            Rect box = Dialog(418, 352);
            Text(R(box.x + 24, box.y + 16, box.width - 48, 24), "指揮端末", 17, Amber, true);
            Text(R(box.x + 24, box.y + 48, box.width - 48, 48), "一時停止", 37, Cream, true);
            Text(R(box.x + 24, box.y + 104, box.width - 48, 30), FieldName, 18, Mist);
            if (Button(R(box.x + 24, box.y + 152, box.width - 48, 56), "作戦に戻る", true)) Submit(G.Resume);
            if (Button(R(box.x + 24, box.y + 218, box.width - 48, 47), "設定", dark: true))
            {
                settingsOpen = true;
                SetSettingsPage(SettingsPage.General);
            }
            if (Button(R(box.x + 24, box.y + 276, box.width - 48, 47), "タイトルへ", dark: true))
            {
                dispatchOpen = true;
                ResetFocus();
            }
        }

        void DrawReturnConfirmation()
        {
            Rect box = Dialog(460, 240);
            Text(R(box.x + 24, box.y + 20, box.width - 48, 44), "タイトルに戻りますか？", 25, Cream, true);
            Text(R(box.x + 24, box.y + 66, box.width - 48, 28), "ここまでの進行を保存します。", 17, Mist);
            if (Button(R(box.x + 24, box.y + 106, box.width - 48, 50), "一時停止に戻る", true))
            {
                dispatchOpen = false;
                ResetFocus();
            }
            if (Button(R(box.x + 24, box.y + 166, box.width - 48, 50), "タイトルに戻る", dark: true))
                Submit(G.Home);
        }

        void SetSettingsPage(SettingsPage page)
        {
            settingsPage = page;
            captureAction = null;
            ControlPreferences.CapturingKey = false;
            bindingStatus = "";
            ResetFocus();
        }

        public bool TryBackFromSettings()
        {
            if (dutyMenuOpen)
            {
                CloseDutyMenu();
                return true;
            }
            if (!settingsOpen) return false;
            if (settingsPage == SettingsPage.General) settingsOpen = false;
            SetSettingsPage(SettingsPage.General);
            return true;
        }

        void OnDisable()
        {
            if (captureAction.HasValue) ControlPreferences.CapturingKey = false;
            captureAction = null;
        }

        void HandleBindingKey()
        {
            Event input = Event.current;
            if (input.type != EventType.KeyDown || !captureAction.HasValue || input.keyCode == KeyCode.None)
                return;

            ControlAction action = captureAction.Value;
            KeyCode key = input.keyCode;
            input.Use();
            if (key == KeyCode.Escape)
            {
                CancelKeyCapture();
                return;
            }

            const EventModifiers modifiers = EventModifiers.Alt | EventModifiers.Control |
                EventModifiers.Command | EventModifiers.Shift;
            if ((input.modifiers & modifiers) != 0)
            {
                bindingStatus = "キーは一つずつ押してください。";
                return;
            }

            if (!ControlPreferences.TryBind(action, key, out ControlAction? conflict))
            {
                bindingStatus = conflict is ControlAction owner ?
                    $"「{BindingLabels[(int)owner]}」で使用中です。別のキーを押してください。" :
                    "このキーは使えません。別のキーを押してください。";
                return;
            }

            captureAction = null;
            ControlPreferences.CapturingKey = false;
            bindingStatus = $"{BindingLabels[(int)action]}に {ControlPreferences.KeyLabel(action)} を割り当てました。";
        }

        void CancelKeyCapture()
        {
            captureAction = null;
            ControlPreferences.CapturingKey = false;
            bindingStatus = "キーの変更を取り消しました。";
        }

        void DrawSettings(System.Action back)
        {
            ModalBackdrop();
            if (settingsPage == SettingsPage.Keyboard) { DrawKeyboardSettings(); return; }
            if (settingsPage == SettingsPage.Touch) { DrawTouchSettings(); return; }

            Rect box = Dialog(572, 454);
            float x = box.x + 24, width = box.width - 48, half = (width - 8) / 2;
            Text(R(x, box.y + 16, width, 49), "設定", 32, Cream, true);
            SettingLevel(x, box.y + 75, width, "全体の音量", G.MasterVolume,
                .1f, 0, 1, G.SetVolume);
            SettingLevel(x, box.y + 133, width, "視点の感度", G.LookSensitivity,
                .25f, .25f, 3, G.SetSensitivity);
            if (Button(R(x, box.y + 194, width, 49),
                $"揺れを抑える　{(G.ReducedMotion ? "オン" : "オフ")}", selected: G.ReducedMotion, dark: true))
                Submit(() => G.SetReducedMotion(!G.ReducedMotion));
            if (Button(R(x, box.y + 251, width, 49),
                $"文字サイズ　{(G.LargeText ? "大" : "標準")}", selected: G.LargeText, dark: true))
                Submit(() => G.SetLargeText(!G.LargeText));
            if (Button(R(x, box.y + 308, half, 51), "キー設定", dark: true))
                SetSettingsPage(SettingsPage.Keyboard);
            if (Button(R(x + half + 8, box.y + 308, half, 51), "タッチ操作", dark: true))
                SetSettingsPage(SettingsPage.Touch);
            if (Button(R(x, box.y + 376, width, 54), "戻る", true))
            {
                back();
                SetSettingsPage(SettingsPage.General);
            }
        }

        void DrawKeyboardSettings()
        {
            Rect box = Dialog(704, 456);
            float x = box.x + 24, width = box.width - 48, half = (width - 12) / 2;
            Text(R(x, box.y + 15, width, 45), "キー設定", 30, Cream, true);
            Text(R(x, box.y + 65, width, 24), "操作を選び、割り当てたいキーを押してください。", 16, Mist);
            Text(R(x, box.y + 90, width, 24), "英字・矢印・Tab・Spaceに対応。Q・Z・Xは地図操作に使います。", 15, Mist);
            for (int i = 0; i < BindingLabels.Length; i++)
            {
                var action = (ControlAction)i;
                bool selected = captureAction == action;
                string label = BindingLabels[i] + "　" + ControlPreferences.KeyLabel(action);
                float columnX = i < 4 ? x : x + half + 12;
                Rect key = R(columnX, box.y + 125 + (i % 4) * 54, half, 48);
                if (Button(key, label, selected: selected, dark: true))
                {
                    captureAction = action;
                    ControlPreferences.CapturingKey = true;
                    bindingStatus = "キーを押してください。Escで取り消せます。";
                }
            }

            Text(R(x, box.y + 344, width, 27), bindingStatus, 16, Amber);
            if (Button(R(x, box.y + 381, 194, 53), "初期設定に戻す", dark: true))
            {
                ControlPreferences.ResetKeys();
                CancelKeyCapture();
                bindingStatus = "キーを初期設定に戻しました。";
            }
            if (Button(R(x + 202, box.y + 381, 160, 53), "入力を取り消す", enabled: captureAction.HasValue, dark: true))
                CancelKeyCapture();
            if (Button(R(box.xMax - 218, box.y + 381, 194, 53), "設定に戻る", true))
                SetSettingsPage(SettingsPage.General);
        }

        void DrawTouchSettings()
        {
            Rect box = Dialog(700, 447);
            float x = box.x + 24, width = box.width - 48;
            Text(R(x, box.y + 15, width, 49), "タッチ操作", 30, Cream, true);
            SettingLevel(x, box.y + 70, width, "見回しの感度", G.LookSensitivity,
                .25f, .25f, 3, G.SetSensitivity);

            Text(R(x, box.y + 130, 348, 24), "射撃ボタンの左右位置", 17, Mist);
            DrawFireChoices(x, box.y + 159, 348, FireHorizontalLabels,
                ControlPreferences.FireHorizontal, ControlPreferences.SetFireHorizontal);
            Text(R(x, box.y + 226, 348, 24), "射撃ボタンの上下位置", 17, Mist);
            DrawFireChoices(x, box.y + 255, 348, FireVerticalLabels,
                ControlPreferences.FireVertical, ControlPreferences.SetFireVertical);

            Rect preview = R(box.xMax - 284, box.y + 143, 260, 148);
            Panel(preview, Ink, Edge);
            Vector2 fire = ControlPreferences.FirePosition;
            float dotX = preview.x + preview.width * fire.x;
            float dotY = preview.yMax - preview.height * fire.y;
            Fill(R(dotX - 6, dotY - 6, 12, 12), Amber);
            Text(R(preview.x + 8, preview.yMax + 8, preview.width - 16, 24),
                $"射撃　{FireHorizontalLabels[ControlPreferences.FireHorizontal]}・{FireVerticalLabels[ControlPreferences.FireVertical]}", 16, Amber);

            if (Button(R(x, box.y + 365, 220, 55), "射撃位置を初期設定に戻す", dark: true))
                ControlPreferences.ResetFirePosition();
            if (Button(R(box.xMax - 244, box.y + 365, 220, 55), "設定に戻る", true))
                SetSettingsPage(SettingsPage.General);
        }

        void DrawFireChoices(float x, float y, float width, string[] labels, int selected, System.Action<int> set)
        {
            float column = (width - 12) / labels.Length;
            for (int i = 0; i < labels.Length; i++)
            {
                int slot = i;
                if (Button(R(x + (column + 6) * i, y, column, 57), labels[i], selected: selected == i, dark: true))
                    Submit(() => set(slot));
            }
        }

        void SettingLevel(float x, float y, float width, string label, float value, float step, float min,
            float max, System.Action<float> change)
        {
            Text(R(x, y, width / 2, 49), label, 18, Cream);
            Text(R(x + width * .44f, y, width * .24f, 49), $"{value:0%}", 22, Amber,
                true, TextAnchor.MiddleCenter);
            if (Button(R(x + width - 106, y, 49, 49), "−", enabled: value > min + .005f, dark: true))
                Submit(() => change(Mathf.Max(min, value - step)));
            if (Button(R(x + width - 49, y, 49, 49), "＋", enabled: value < max - .005f, dark: true))
                Submit(() => change(Mathf.Min(max, value + step)));
        }

        void DrawDebrief()
        {
            if (G.IsDuty) { DrawDutyDebrief(); return; }
            Photo(desk, new Color(0, 0, 0, .44f));
            Rect box = R(w * .28f, 25, w * .66f, h - 50);
            Panel(box, Paper, Ink);
            Fill(R(box.x, box.y, box.width, 6), G.Won ? new Color32(41, 96, 62, 255) : Rail);
            float x = box.x + 26, width = box.width - 52;
            Text(R(x, box.y + 19, width, 25), $"非常輸送記録　{G.MissionIndex + 1:00}号", 16, Dim, true);
            Text(R(x, box.y + 47, width, 52), G.Won ? "避難輸送完了" : "作戦中止", 38, Ink, true);
            Text(R(x, box.y + 105, width, 36), G.MissionName(G.MissionIndex), 22, Ink);
            Fill(R(x, box.y + 152, width, 1), Dim);
            RecordLine(x, box.y + 164, width, "救出人数", $"{G.Saved} / {G.Population}人");
            RecordLine(x, box.y + 208, width, "避難中に失った住民", $"{G.Dead}人");
            RecordLine(x, box.y + 252, width, "搬入した資材", $"{G.StockDelivered}");
            RecordLine(x, box.y + 296, width, "作戦時間", Clock(G.Elapsed));
            Text(R(x,box.y+341,width,28),"追加要請　"+GameSession.RequestLabel(G.RequestStatus),16,Dim);

            float y = box.yMax - 72;
            float side = width * .29f;
            if (Button(R(x, y, side, 51), "作戦一覧")) Submit(() => G.Brief(G.MissionIndex));
            if (Button(R(x + side + 8, y, side, 51), "最初から")) Submit(G.Deploy);
            if (G.Won)
            {
                if (Button(R(x + side * 2 + 16, y, width - side * 2 - 16, 51),
                    G.MissionIndex == MissionCount - 1 ? "最終報告へ" : "次の作戦へ", true))
                    Submit(G.DebriefNext);
            }
            else if (Button(R(x + side * 2 + 16, y, width - side * 2 - 16, 51), "途中から再挑戦", true))
                Submit(G.RetryCheckpoint);
        }

        void DrawEnding()
        {
            Photo(station, new Color(0, 0, 0, .55f));
            if (creditsOpen) { DrawCredits(() => creditsOpen = false); return; }
            if (requestLog) { DrawRequestRecords(); return; }
            Rect box = Dialog(558, 374);
            Text(R(box.x + 28, box.y + 28, box.width - 56, 26), "輸送記録　最終報告", 18, Amber, true);
            Text(R(box.x + 28, box.y + 69, box.width - 56, 55), "最終便が出発", 42, Cream, true);
            Text(R(box.x + 28, box.y + 130, box.width - 56, 38), $"全作戦の救出記録　{G.CampaignRescued}人", 22, Cream);
            Paragraph(R(box.x + 28, box.y + 182, box.width - 56, 66),
                "車両基地から最後の避難車両が出発した。\n対策本部は八つの作戦の輸送記録を受領した。", 19, Mist);
            if(Button(R(box.x+28,box.y+230,box.width-56,43),$"現場要請の記録　{G.CompletedRequests} / 8件完了",dark:true))
                requestLog=true;
            if (Button(R(box.x + 28, box.y + 283, 230, 55), "クレジット", dark: true))
            {
                creditsOpen = true;
                ResetFocus();
            }
            if (Button(R(box.xMax - 258, box.y + 283, 230, 55), "タイトルへ", true)) Submit(G.Home);
        }

        void DrawCredits(System.Action back)
        {
            ModalBackdrop();
            Rect box = Dialog(542, 388);
            Text(R(box.x + 26, box.y + 24, box.width - 52, 52), "クレジット", 34, Cream, true);
            Paragraph(R(box.x + 26, box.y + 91, box.width - 52, 205),
                "制作　100challenge\nゲームエンジン　Unity\n背景原画　Moss-image（ComfyUI）\n書体　Noto Sans JP（SIL Open Font License）\n無線音声　HTS Voice “Mei”\nMMDAgent Project Team（CC BY 3.0）",
                20, Mist);
            if (Button(R(box.x + 26, box.y + 305, box.width - 52, 54), "戻る", true))
            {
                back();
                ResetFocus();
            }
        }

        void RecordLine(float x, float y, float width, string label, string value)
        {
            Text(R(x, y, width * .64f, 37), label, 19, Ink);
            Text(R(x, y, width, 37), value, 24, Ink, true, TextAnchor.MiddleRight);
            Fill(R(x, y + 39, width, 1), new Color32(180, 168, 143, 255));
        }

        Rect Dialog(float width, float height)
        {
            Rect box = R((w - width) / 2, (h - height) / 2, width, height);
            Panel(box, Case, Edge);
            Fill(R(box.x, box.y, box.width, 4), Rail);
            return box;
        }

        void ModalBackdrop()
        {
            Fill(R(-safeArea.x / scale, (safeArea.yMax - Screen.height) / scale,
                Screen.width / scale, Screen.height / scale), new Color(0, 0, 0, .58f));
        }
    }
}
