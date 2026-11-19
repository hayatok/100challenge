using System;
using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    public enum ControlAction
    {
        Forward, Backward, StrafeLeft, StrafeRight, Reload, Dodge, FieldAction, SwitchView
    }

    public static class ControlPreferences
    {
        const string KeyPrefix = "evac.controls.";
        const string FireXKey = "evac.controls.fireX";
        const string FireYKey = "evac.controls.fireY";
        const int DefaultFireSlot = 1;

        static readonly KeyCode[] DefaultKeys =
        {
            KeyCode.W, KeyCode.S, KeyCode.A, KeyCode.D, KeyCode.R, KeyCode.Space, KeyCode.F, KeyCode.Tab
        };
        static readonly float[] FireX = { .77f, .86f, .91f };
        static readonly float[] FireY = { .25f, .28f, .32f };
        static KeyCode[] keys;
        static int horizontal = -1, vertical = -1;

        public static bool CapturingKey { get; internal set; }
        public static int FireHorizontal => ReadSlot(ref horizontal, FireXKey);
        public static int FireVertical => ReadSlot(ref vertical, FireYKey);
        public static Vector2 FirePosition => new Vector2(FireX[FireHorizontal], FireY[FireVertical]);

        public static KeyCode GetKey(ControlAction action) => Keys[(int)action];
        public static bool Pressed(ControlAction action) => !CapturingKey && Input.GetKeyDown(GetKey(action));
        public static bool Held(ControlAction action) => !CapturingKey && Input.GetKey(GetKey(action));

        public static Vector2 Movement()
        {
            return new Vector2(
                (Held(ControlAction.StrafeRight) ? 1 : 0) - (Held(ControlAction.StrafeLeft) ? 1 : 0),
                (Held(ControlAction.Forward) ? 1 : 0) - (Held(ControlAction.Backward) ? 1 : 0));
        }

        public static string KeyLabel(ControlAction action)
        {
            KeyCode key = GetKey(action);
            return key switch
            {
                KeyCode.UpArrow => "↑",
                KeyCode.DownArrow => "↓",
                KeyCode.LeftArrow => "←",
                KeyCode.RightArrow => "→",
                _ => key.ToString()
            };
        }

        internal static bool TryBind(ControlAction action, KeyCode key, out ControlAction? conflict)
        {
            conflict = null;
            if (!CanBind(key)) return false;
            int slot = (int)action;
            int owner = Array.IndexOf(Keys, key);
            if (owner >= 0 && owner != slot)
            {
                conflict = (ControlAction)owner;
                return false;
            }

            Keys[slot] = key;
            PlayerPrefs.SetInt(KeyPrefix + action, (int)key);
            PlayerPrefs.Save();
            return true;
        }

        internal static void ResetKeys()
        {
            keys = (KeyCode[])DefaultKeys.Clone();
            for (int i = 0; i < keys.Length; i++)
                PlayerPrefs.DeleteKey(KeyPrefix + (ControlAction)i);
            PlayerPrefs.Save();
        }

        internal static void SetFireHorizontal(int slot) => SaveSlot(ref horizontal, FireXKey, slot);
        internal static void SetFireVertical(int slot) => SaveSlot(ref vertical, FireYKey, slot);

        internal static void ResetFirePosition()
        {
            horizontal = vertical = DefaultFireSlot;
            PlayerPrefs.DeleteKey(FireXKey);
            PlayerPrefs.DeleteKey(FireYKey);
            PlayerPrefs.Save();
        }

        static KeyCode[] Keys
        {
            get
            {
                if (keys != null) return keys;
                keys = (KeyCode[])DefaultKeys.Clone();
                var used = new HashSet<KeyCode>();
                for (int i = 0; i < keys.Length; i++)
                {
                    KeyCode key = (KeyCode)PlayerPrefs.GetInt(KeyPrefix + (ControlAction)i, (int)DefaultKeys[i]);
                    if (!CanBind(key) || !used.Add(key))
                    {
                        keys = (KeyCode[])DefaultKeys.Clone();
                        break;
                    }
                    keys[i] = key;
                }
                return keys;
            }
        }

        static bool CanBind(KeyCode key)
        {
            // Q and Z/X are fixed RTS shortcuts. They must remain free for a shared view-switch key.
            bool letter = key >= KeyCode.A && key <= KeyCode.Z &&
                key != KeyCode.Q && key != KeyCode.X && key != KeyCode.Z;
            return letter || key == KeyCode.Tab || key == KeyCode.Space ||
                key == KeyCode.UpArrow || key == KeyCode.DownArrow ||
                key == KeyCode.LeftArrow || key == KeyCode.RightArrow;
        }

        static int ReadSlot(ref int current, string key)
        {
            if (current < 0) current = Mathf.Clamp(PlayerPrefs.GetInt(key, DefaultFireSlot), 0, 2);
            return current;
        }

        static void SaveSlot(ref int current, string key, int slot)
        {
            current = Mathf.Clamp(slot, 0, 2);
            PlayerPrefs.SetInt(key, current);
            PlayerPrefs.Save();
        }
    }
}
