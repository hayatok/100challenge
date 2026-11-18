using UnityEngine;

namespace Evac
{
    internal static class FieldTouches
    {
#if UNITY_WEBGL && !UNITY_EDITOR
        // Read DOM contacts once per rendered frame so the UI and the field see the same phases.
        [System.Runtime.InteropServices.DllImport("__Internal")]
        static extern int ReadFieldTouches([System.Runtime.InteropServices.Out] float[] samples, int capacity);

        const int Capacity = 16;
        const int Stride = 6;
        static readonly float[] samples = new float[Capacity * Stride];
        static int frame = -1;
        static int count;

        public static int Count
        {
            get
            {
                if (frame != Time.frameCount)
                {
                    frame = Time.frameCount;
                    count = ReadFieldTouches(samples, Capacity);
                }
                return count;
            }
        }

        public static Touch Get(int index)
        {
            int i = index * Stride;
            return new Touch
            {
                fingerId = (int)samples[i],
                phase = (TouchPhase)(int)samples[i + 1],
                position = new Vector2(samples[i + 2] * Screen.width, samples[i + 3] * Screen.height),
                deltaPosition = new Vector2(samples[i + 4] * Screen.width, samples[i + 5] * Screen.height)
            };
        }
#else
        public static int Count => Input.touchCount;
        public static Touch Get(int index) => Input.GetTouch(index);
#endif
    }
}
