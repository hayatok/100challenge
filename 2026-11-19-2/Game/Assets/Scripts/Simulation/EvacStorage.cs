using System;
using System.IO;
using UnityEngine;

namespace Evac
{
    internal static class EvacStorage
    {
        internal static string TestDirectory;
        static string DirectoryPath => TestDirectory ?? Application.persistentDataPath;

        internal static bool Exists(string slot)
        {
            if (Application.platform == RuntimePlatform.WebGLPlayer && TestDirectory == null) return PlayerPrefs.HasKey("evac-" + slot);
            var path = PathFor(slot);
            return File.Exists(path) || File.Exists(path + ".bak");
        }

        static string PathFor(string slot) => Path.Combine(DirectoryPath, "evac-" + slot + ".json");

        internal static bool Write<T>(string slot, T data)
        {
            string path = PathFor(slot);
            try
            {
                if (Application.platform == RuntimePlatform.WebGLPlayer && TestDirectory == null)
                {
                    PlayerPrefs.SetString("evac-" + slot, JsonUtility.ToJson(data)); PlayerPrefs.Save(); return true;
                }
                Directory.CreateDirectory(DirectoryPath);
                File.WriteAllText(path + ".tmp", JsonUtility.ToJson(data));
                if (File.Exists(path))
                {
                    try { File.Replace(path + ".tmp", path, path + ".bak"); }
                    catch (PlatformNotSupportedException)
                    {
                        File.Copy(path,path + ".bak",true);
                        File.Copy(path + ".tmp",path,true);
                        File.Delete(path + ".tmp");
                    }
                }
                else File.Move(path + ".tmp", path);
                return true;
            }
            catch (Exception error) when (error is IOException || error is UnauthorizedAccessException || error is NotSupportedException || error is PlayerPrefsException)
            {
                Debug.LogWarning("Save failed (" + slot + "): " + error.Message);
                return false;
            }
        }

        internal static T Read<T>(string slot, Func<T, bool> valid) where T : class
        {
            string path = PathFor(slot);
            if (Application.platform == RuntimePlatform.WebGLPlayer && TestDirectory == null)
            {
                try
                {
                    var value = JsonUtility.FromJson<T>(PlayerPrefs.GetString("evac-" + slot, ""));
                    return value != null && valid(value) ? value : null;
                }
                catch (ArgumentException) { return null; }
            }
            foreach (string candidate in new[] {path, path + ".bak"})
            {
                try
                {
                    if (!File.Exists(candidate)) continue;
                    var value = JsonUtility.FromJson<T>(File.ReadAllText(candidate));
                    if (value != null && valid(value)) return value;
                }
                catch (Exception error) when (error is IOException || error is UnauthorizedAccessException || error is ArgumentException)
                {
                    Debug.LogWarning("Could not read " + slot + ": " + error.Message);
                }
            }
            return null;
        }
    }
}
