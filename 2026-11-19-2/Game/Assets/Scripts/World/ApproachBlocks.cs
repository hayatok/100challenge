using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    // The evacuation annexes use the same measured footprints as the Blender bake.
    internal static class ApproachBlocks
    {
        public const float StreetEnd = 90.5f;
        public static Vector3 BusCenter(Vector3 door,int bus,float heading)
        {
            Vector3 offset=bus==0?new Vector3(1.82f,0,1.8f):new Vector3(-1.35f,0,-.8f);
            return door+Quaternion.Euler(0,heading,0)*offset;
        }
        [System.Serializable] internal sealed class Footprint
        {
            public float x, z, width, depth, height;
        }
        [System.Serializable] sealed class Layout { public Footprint[] walls; }
        static Footprint[] template;
        static int Direction(int mission, int sector) => ((mission + sector) & 1) == 0 ? 1 : -1;
        static int Wing(int mission, int sector) => ((sector / 2 + mission / 2) & 1) == 0 ? 1 : -1;
        public static Vector3 FieldStation(int mission, int sector)
        {
            int end = Direction(mission, sector), side = Wing(mission, sector);
            return new Vector3(side * 9.7f, 0, end * (side > 0 ? 60 : 77));
        }
        public static Vector3 Relay(int mission, int sector)
        {
            int end = Direction(mission, sector), side = -Wing(mission, sector);
            return new Vector3(side * 9.7f, 0, end * (side > 0 ? 60 : 77));
        }
        public static IEnumerable<Footprint> Solids(int mission)
        {
            if (template == null)
            {
                var asset = Resources.Load<TextAsset>("World/ApproachFootprints");
                template = JsonUtility.FromJson<Layout>(asset.text).walls;
            }
            foreach (int end in new[] { -1, 1 })
                foreach (var box in template)
                    yield return new Footprint { x = box.x, z = end * box.z, width = box.width, depth = box.depth, height = box.height };
        }
    }
}
