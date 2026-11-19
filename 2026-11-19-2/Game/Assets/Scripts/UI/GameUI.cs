using System;
using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    [RequireComponent(typeof(GameSession))]
    public sealed partial class GameUI : MonoBehaviour
    {
        static readonly Color Ink = new Color32(25, 28, 28, 255);
        static readonly Color Case = new Color32(24, 29, 30, 246);
        static readonly Color Edge = new Color32(76, 86, 82, 255);
        static readonly Color Rail = new Color32(174, 56, 37, 255);
        static readonly Color Amber = new Color32(255, 207, 119, 255);
        static readonly Color Paper = new Color32(249, 240, 218, 255);
        static readonly Color Cream = new Color32(255, 248, 228, 255);
        static readonly Color Mist = new Color32(191, 200, 187, 255);
        static readonly Color Green = new Color32(178, 221, 172, 255);
        static readonly Color Dim = new Color32(100, 101, 89, 255);

        readonly List<Rect> pointerBlocks = new List<Rect>(12);
        readonly Dictionary<(int, bool, TextAnchor), GUIStyle> textStyles = new();
        readonly Dictionary<int, Vector2> uiTouchStarts = new();
        GameSession G;
        Font japanese;
        Texture2D station, desk;
        GUIStyle hitStyle;
        readonly GUIContent measurement = new GUIContent();
        float w, h, scale;
        Rect safeArea;
        bool settingsOpen, creditsOpen, dispatchOpen, fieldPanel, orderPickerOpen, continueFailed;
        bool rosterFolded, ordersFolded, commandGuideSeen, directGuideSeen;
        float guideUntil;
        Action queuedCommand;
        string lastPhase, lastMode;
        int focusIndex = -1, controlIndex, controlCount;
        bool keyboardSubmit;
        int lastTouchFrame = -2, tapFrame = -1;
        Vector2 tapStart, tapEnd;

        void Awake()
        {
            G = GetComponent<GameSession>();
            japanese = Resources.Load<Font>("UI/NotoSansJP");
            station = Resources.Load<Texture2D>("UI/TitleStation");
            desk = Resources.Load<Texture2D>("UI/DispatchDesk");
        }

        void Update()
        {
            Action action = queuedCommand;
            queuedCommand = null;
            action?.Invoke();
            CaptureTouchTaps();
            if (G.Phase == "Playing" && Input.GetKeyDown(KeyCode.F1)) ToggleGuide();
        }

        void CaptureTouchTaps()
        {
            int count = FieldTouches.Count;
            if (count > 0) lastTouchFrame = Time.frameCount;
            for (int i = 0; i < count; i++)
            {
                Touch touch = FieldTouches.Get(i);
                switch (touch.phase)
                {
                    case TouchPhase.Began:
                        if (BlocksPointer(touch.position)) uiTouchStarts[touch.fingerId] = touch.position;
                        break;
                    case TouchPhase.Ended:
                        if (uiTouchStarts.Remove(touch.fingerId, out Vector2 start))
                        {
                            tapFrame = Time.frameCount;
                            tapStart = start;
                            tapEnd = touch.position;
                        }
                        break;
                    case TouchPhase.Canceled:
                        uiTouchStarts.Remove(touch.fingerId);
                        break;
                }
            }
        }

        public bool BlocksPointer(Vector2 screenBottomLeft)
        {
            if (G.Phase != "Playing" || FieldOverlay) return true;
            if (scale <= 0f) return false;
            Vector2 point = ToLogical(screenBottomLeft);
            foreach (Rect rect in pointerBlocks)
                if (rect.Contains(point)) return true;
            return false;
        }

        Vector2 ToLogical(Vector2 point) => new Vector2((point.x - safeArea.x) / scale, (safeArea.yMax - point.y) / scale);

        void OnGUI()
        {
            if (G == null) return;
            safeArea = Screen.safeArea;
            if (safeArea.width == 0 || safeArea.height == 0) return;
            bool desktopField = G.Phase == "Playing" && !G.TouchUI;
            float referenceWidth = desktopField ? 1280 : 860;
            float referenceHeight = desktopField ? 720 : 500;
            scale = Mathf.Min(safeArea.height / referenceHeight, safeArea.width / referenceWidth);
            w = safeArea.width / scale;
            h = safeArea.height / scale;
            if (hitStyle == null) hitStyle = new GUIStyle();
            if (Event.current.type == EventType.Repaint) pointerBlocks.Clear();
            if (lastPhase != G.Phase)
            {
                bookOpen = requestOpen = requestLog = fieldDispatchOpen = fleetOpen = searchDeskOpen = false;
                dutyMenuOpen = false;
                settingsOpen = creditsOpen = dispatchOpen = fieldPanel = orderPickerOpen = false;
                continueFailed = false;
                if (G.Phase == "Title" || G.Phase == "Briefing")
                {
                    rosterFolded = ordersFolded = G.TouchUI;
                    commandGuideSeen = directGuideSeen = false;
                    guideUntil = 0;
                    lastMode = null;
                }
                uiTouchStarts.Clear();
                ResetFocus();
                lastPhase = G.Phase;
            }

            if (G.Phase == "Playing" && lastMode != G.Mode)
            {
                bookOpen = requestOpen = fieldDispatchOpen = fleetOpen = searchDeskOpen = false;
                fieldPanel = orderPickerOpen = false;
                lastMode = G.Mode;
                if (lastMode == "FPS" && !directGuideSeen)
                {
                    directGuideSeen = true;
                    guideUntil = Time.unscaledTime + 4.5f;
                }
                if (lastMode == "RTS" && !commandGuideSeen)
                {
                    commandGuideSeen = true;
                    guideUntil = Time.unscaledTime + 5;
                }
            }

            controlIndex = 0;
            keyboardSubmit = false;
            if (ControlPreferences.CapturingKey) HandleBindingKey();
            else if (G.Phase != "Playing" && Event.current.type == EventType.KeyDown)
                MenuKeys();

            int depth = GUI.depth;
            Matrix4x4 matrix = GUI.matrix;
            GUI.depth = -10;
            GUI.matrix = Matrix4x4.TRS(new Vector3(safeArea.x, Screen.height - safeArea.yMax, 0),
                Quaternion.identity, new Vector3(scale, scale, 1));
            switch (G.Phase)
            {
                case "Title": DrawTitle(); break;
                case "Briefing": DrawBriefing(); break;
                case "Playing":
                    if (bookOpen && !G.IsDuty) DrawBook();
                    else if (searchDeskOpen && !G.IsDuty) DrawSearchDesk();
                    else if (fieldDispatchOpen && !G.IsDuty) FieldDesk();
                    else if (fleetOpen && G.HasFleet) FleetDesk();
                    else if (requestOpen && !G.IsDuty) DrawRequest();
                    else if (fieldPanel) DrawFacilities();
                    else if (G.Mode == "FPS") DrawDirect();
                    else DrawCommand();
                    break;
                case "Paused": DrawPause(); break;
                case "Debrief": DrawDebrief(); break;
                case "Ending": DrawEnding(); break;
            }
            controlCount = controlIndex;
            GUI.matrix = matrix;
            GUI.depth = depth;
        }

        void ResetFocus() => focusIndex = -1;

        void MenuKeys()
        {
            var key = Event.current.keyCode;
            if (controlCount > 0 && (key == KeyCode.Tab || key == KeyCode.UpArrow || key == KeyCode.DownArrow))
            {
                int step = key == KeyCode.UpArrow || (key == KeyCode.Tab && Event.current.shift) ? -1 : 1;
                focusIndex = focusIndex < 0 && step < 0 ? controlCount - 1 : (focusIndex + step + controlCount) % controlCount;
                Event.current.Use();
            }
            else if (focusIndex >= 0 && (key == KeyCode.Return || key == KeyCode.KeypadEnter))
            {
                keyboardSubmit = true;
                Event.current.Use();
            }
        }

        static Rect R(float x, float y, float width, float height) => new Rect(x, y, width, height);

        static void Fill(Rect rect, Color color)
        {
            Color previous = GUI.color;
            GUI.color = color;
            GUI.DrawTexture(rect, Texture2D.whiteTexture);
            GUI.color = previous;
        }

        static void Outline(Rect box, Color color, float thickness = 1)
        {
            Fill(R(box.x, box.y, box.width, thickness), color);
            Fill(R(box.x, box.yMax - thickness, box.width, thickness), color);
            Fill(R(box.x, box.y, thickness, box.height), color);
            Fill(R(box.xMax - thickness, box.y, thickness, box.height), color);
        }

        void Mark(Rect rect)
        {
            if (Event.current.type == EventType.Repaint)
                pointerBlocks.Add(rect);
        }

        void Panel(Rect box, Color color, Color outline, bool interactive = false)
        {
            Fill(box, color);
            Outline(box, outline);
            if (interactive) Mark(box);
        }

        GUIStyle TextStyle(int size, bool bold, TextAnchor anchor)
        {
            var key = (size, bold, anchor);
            if (!textStyles.TryGetValue(key, out GUIStyle style))
            {
                style = new GUIStyle
                {
                    font = japanese != null ? japanese : GUI.skin.font,
                    alignment = anchor,
                    fontSize = size,
                    fontStyle = bold ? FontStyle.Bold : FontStyle.Normal,
                    clipping = TextClipping.Clip
                };
                style.normal.textColor = Color.white;
                textStyles.Add(key, style);
            }
            return style;
        }

        void Text(Rect rect, string text, int size, Color color, bool bold = false, TextAnchor anchor = TextAnchor.MiddleLeft)
        {
            Color old = GUI.contentColor;
            GUI.contentColor = color;
            GUI.Label(rect, text, TextStyle(size, bold, anchor));
            GUI.contentColor = old;
        }

        void Paragraph(Rect rect, string text, int size, Color color)
        {
            GUIStyle style = TextStyle(size, false, TextAnchor.UpperLeft);
            bool wrap = style.wordWrap;
            style.wordWrap = true;
            Text(rect, text, size, color, false, TextAnchor.UpperLeft);
            style.wordWrap = wrap;
        }

        float ParagraphHeight(string text, int size, float width)
        {
            if (string.IsNullOrEmpty(text)) return 0;
            GUIStyle style = TextStyle(size, false, TextAnchor.UpperLeft);
            bool wrap = style.wordWrap;
            style.wordWrap = true;
            measurement.text = text;
            float height = style.CalcHeight(measurement, width);
            style.wordWrap = wrap;
            return height;
        }

        bool Button(Rect box, string label, bool primary = false, bool enabled = true, bool selected = false, bool dark = false)
        {
#if UNITY_WEBGL && EVAC_WEB_TEST && !UNITY_EDITOR
            if(enabled)ReportButton(box,label);
#endif
            enabled &= GUI.enabled;
            int index = enabled ? controlIndex++ : -1;
            bool focused = enabled && index == focusIndex && G.Phase != "Playing";
            bool hovered = enabled && box.Contains(Event.current.mousePosition);
            Color background = !enabled ? (dark ? Case : new Color32(209, 202, 184, 255)) : primary ? Rail : dark ? Case : Cream;
            if (enabled && hovered) background = Color.Lerp(background, dark ? Color.white : Amber, .22f);
            Fill(box, background);
            Outline(box, focused || selected ? Amber : dark ? Edge : Ink, focused || selected ? 3f : 1f);
            int fontSize = G.LargeText ? 18 : 16;
            Text(box, label, fontSize, !enabled ? (dark ? Mist : Dim) : primary || dark ? Cream : Ink,
                primary || selected, TextAnchor.MiddleCenter);
            Mark(box);

            bool wasEnabled = GUI.enabled;
            GUI.enabled = enabled;
            bool clicked = GUI.Button(box, GUIContent.none, hitStyle) && Time.frameCount > lastTouchFrame + 1;
            if (enabled && tapFrame == Time.frameCount && Event.current.type == EventType.Repaint &&
                box.Contains(ToLogical(tapStart)) && box.Contains(ToLogical(tapEnd)))
            {
                clicked = true;
                tapFrame = -1;
            }
            GUI.enabled = wasEnabled;
#if UNITY_WEBGL && EVAC_WEB_TEST && !UNITY_EDITOR
            if(enabled && clicked)InspectClick(label);
#endif
            return enabled && (clicked || (focused && keyboardSubmit));
        }

        void Photo(Texture2D image, Color shade)
        {
            var backdrop = R(-safeArea.x / scale, (safeArea.yMax - Screen.height) / scale, Screen.width / scale, Screen.height / scale);
            Fill(backdrop, Ink);
            if (image != null) GUI.DrawTexture(backdrop, image, ScaleMode.ScaleAndCrop);
            Fill(backdrop, shade);
        }

        void Bar(Rect box, float progress, Color foreground)
        {
            Fill(box, Edge);
            Fill(R(box.x, box.y, box.width * Mathf.Clamp01(progress), box.height), foreground);
        }

        void Submit(Action action) => queuedCommand = action;

        static string Clock(float seconds)
        {
            int total = Mathf.Max(0, Mathf.CeilToInt(seconds));
            return $"{total / 60:00}:{total % 60:00}";
        }
    }
}
