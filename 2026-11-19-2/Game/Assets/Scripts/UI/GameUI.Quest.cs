using UnityEngine;

namespace Evac
{
    public sealed partial class GameUI
    {
        bool questChoices;
        int questFocus, questPhase;
        ChapterMemory observedQuest;
        string questResult;
        float questResultUntil;

        Vector2 QuestScreen(Vector3 world) => MarketMapPoint(world);

        Rect QuestBox(Vector2 point, float width, float height)
        {
            float minX = 14, maxX = w - 14 - width;
            float top = BoardHeight + 58;
            float bottom = Mathf.Max(top, h * .70f - height);
            return R(Mathf.Clamp(point.x - width / 2, minX, maxX),
                Mathf.Clamp(point.y - height - 18, top, bottom), width, height);
        }

        Vector2 QuestVisiblePoint(Vector2 point) => new Vector2(
            Mathf.Clamp(point.x, 9, w - 9), Mathf.Clamp(point.y, BoardHeight + 18, h * .72f));

        void ObserveQuest()
        {
            if (observedQuest != Field.QuestMemory)
            {
                observedQuest = Field.QuestMemory;
                questPhase = Field.ChapterPhase;
                questChoices = false;
                questFocus = 0;
                questResult = null;
            }
            int phase = Field.ChapterPhase;
            if (phase != questPhase)
            {
                if ((questPhase == 1 && phase == 2) || (questPhase == 3 && phase == 4))
                {
                    questResult = (questPhase == 1 ? "前哨完了" : "撤収完了") + "　" + Field.ChapterBenefitName;
                    questResultUntil = Field.Elapsed + 5;
                }
                questPhase = phase;
                questChoices = false;
                questFocus = 0;
            }
            if (!string.IsNullOrEmpty(questResult) && Field.Elapsed < questResultUntil)
            {
                Rect receipt = R((w - 392) / 2, h - 120, 392, 42);
                Panel(receipt, Case, Green, true);
                Text(receipt, questResult, BodySize, Green, true, TextAnchor.MiddleCenter);
            }
        }

        void DrawQuestDirect()
        {
            ObserveQuest();
            if (!Field.CanTakeQuestDirectly)
            {
                questChoices = false;
                return;
            }
            if (questChoices)
            {
                DrawQuestChoices(R((w - 330) / 2, BoardHeight + 16, 330, 142), direct: true);
                return;
            }

            bool chosen = Field.ChapterChoice >= 0;
            Rect button = R((w - 250) / 2, BoardHeight + 16, 250, 58);
            string label = chosen ? "現場を引き受ける" : "現場を見る";
            if (Button(button, label, primary: true) || QuestEnter())
            {
                if (chosen) Submit(() => Field.TakeQuestDirectly());
                else { questChoices = true; questFocus = 0; }
            }
            if (!G.TouchUI)
                Text(R(button.x, button.yMax + 3, button.width, 21), "Enter", 15, Cream, true, TextAnchor.MiddleCenter);
        }

        bool QuestEnter()
        {
            Event e = Event.current;
            if (e.type != EventType.KeyDown ||
                (e.keyCode != KeyCode.Return && e.keyCode != KeyCode.KeypadEnter)) return false;
            e.Use();
            return true;
        }

        void DrawQuestMap()
        {
            ObserveQuest();
            if (!ChapterTask || G.IsDuty) return;
            bool chosen = Field.ChapterChoice >= 0;
            Unit agent = Field.QuestAgent;
            Vector3 target = chosen ? Field.QuestTarget(agent) : Field.QuestIncidentPosition;
            Vector2 projected = QuestScreen(target);
            Vector2 destination = QuestVisiblePoint(projected);
            float width = questChoices ? 330 : agent != null ? 280 : 264;
            float height = questChoices ? 172 : agent != null ? 66 : 60;
            Rect card = QuestBox(projected, width, height);
            Vector2 anchor = new Vector2(Mathf.Clamp(destination.x, card.x + 8, card.xMax - 8),
                destination.y < card.center.y ? card.y : card.yMax);
            Color accent = agent != null ? Green : Amber;
            if (agent != null)
            {
                Vector2 crew = QuestVisiblePoint(QuestScreen(agent.pos));
                DrawMarketLine(crew, destination, Green, true);
                Panel(R(crew.x - 6, crew.y - 6, 12, 12), Green, Ink);
            }
            DrawMarketLine(anchor, destination, accent, false);
            Outline(R(destination.x - 8, destination.y - 8, 16, 16), accent, 3);
            if (agent != null)
            {
                questChoices = false;
                float distance = Vector2.Distance(new Vector2(agent.pos.x, agent.pos.z), new Vector2(target.x, target.z));
                Panel(card, Case, Green, true);
                string state = distance > 2 ? $"{Field.QuestDestination} {Mathf.CeilToInt(distance)}m" : "現場に到着";
                if (Field.ChapterNeedsSupport)
                {
                    if (Field.QuestSignalPortable)
                        state = Field.QuestSignalReady ? "中継先に到着" : $"中継先まで {Mathf.CeilToInt(distance)}m";
                    else if (Field.QuestSignalReady)
                        state = "両端に到着";
                    else
                        state = Field.QuestSignalStationReached(agent) ? "もう一方の到着待ち" : $"合図の地点まで {Mathf.CeilToInt(distance)}m";
                }
                if (Field.QuestWork > 0) state = $"修理中　{Mathf.RoundToInt(Field.QuestWork * 100)}%";
                Text(R(card.x + 10, card.y, width - 20, 33), G.SquadName(agent.squad) + "　" + state, BodySize, Green, true);
                Text(R(card.x + 10, card.y + 32, width - 20, 30), Field.ChapterOptionTitle(Field.ChapterChoice), BodySize, Cream);
                return;
            }
            if (questChoices && !chosen)
            {
                DrawQuestChoices(card);
                return;
            }
            questChoices = false;
            string label = chosen ? G.SquadName(G.QuestSquad) + "を派遣" : Field.ChapterTitle + "　現場を見る";
            if (Button(card, label, primary: true) || QuestEnter())
            {
                if (chosen) Submit(() => G.SendQuestTeam(Field.ChapterChoice));
                else { questChoices = true; questFocus = 0; }
            }
        }

        void DrawQuestChoices(Rect card, bool direct = false)
        {
            Panel(card, Case, Amber, true);
            Text(R(card.x + 12, card.y + 1, card.width - 70, 38),
                direct ? "どちらを引き受ける？" : G.SquadName(G.QuestSquad) + "をどちらへ送る？", BodySize, Amber, true);
            if (Button(R(card.xMax - 66, card.y + 3, 62, 36), "戻る", dark: true))
            {
                questChoices = false;
                return;
            }
            Event e = Event.current;
            if (e.type == EventType.KeyDown && (e.keyCode == KeyCode.UpArrow || e.keyCode == KeyCode.DownArrow))
            {
                questFocus = 1 - questFocus;
                e.Use();
            }
            bool enter = QuestEnter();
            for (int branch = 0; branch < 2; branch++)
            {
                float rowHeight = direct ? 46 : 60;
                Rect row = R(card.x + 6, card.y + 42 + branch * (rowHeight + 4), card.width - 12, rowHeight);
                if (Button(row, Field.ChapterOptionTitle(branch), selected: questFocus == branch, dark: true)
                    || (enter && questFocus == branch))
                {
                    int choice = branch;
                    if (direct)
                    {
                        Submit(() =>
                        {
                            if (!Field.CanTakeQuestDirectly || Field.ChapterChoice >= 0) return;
                            G.ChooseResponse(choice);
                            Field.TakeQuestDirectly();
                        });
                    }
                    else Submit(() => G.SendQuestTeam(choice));
                    questChoices = false;
                }
            }
        }
    }
}
