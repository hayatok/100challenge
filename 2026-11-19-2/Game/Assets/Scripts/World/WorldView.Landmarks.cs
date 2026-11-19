using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    internal static class DistrictLandmarks
    {
        [System.Serializable] sealed class Layout { public Solid[] solids; }
        [System.Serializable] sealed class Solid
        {
            public int region;
            public float x, z, width, depth, height;
        }
        static Solid[] measured;

        public static IEnumerable<ApproachBlocks.Footprint> Solids(int missionIndex)
        {
            if (measured == null)
            {
                var data = Resources.Load<TextAsset>("World/DistrictLandmarks");
                measured = JsonUtility.FromJson<Layout>(data.text).solids;
                Resources.UnloadAsset(data);
            }
            int region = missionIndex / 2;
            foreach (var part in measured)
                if (part.region == region)
                    yield return new ApproachBlocks.Footprint {
                        x=part.x, z=part.z, width=part.width, depth=part.depth, height=part.height
                    };
        }
    }

    public sealed partial class WorldView
    {
        readonly GameObject[] landmarkRoofs = new GameObject[2];
        Transform landmarkGantry;
        float gantryClock;

        void BuildLandmarks(int region)
        {
            string name = "landmark" + region;
            MakeObject("Central district landmark", GetMesh(name), district.transform);
            landmarkGantry = null;
            landmarkRoofs[0] = landmarkRoofs[1] = null;
            if (region == 0 || region == 3)
                landmarkRoofs[0] = MakeObject("Landmark roof", GetMesh(name+"Roof"), district.transform);
            if (region == 0)
                landmarkRoofs[1] = MakeObject("Arcade wire glazing", GetMesh(name+"Glazing"), district.transform);
            if (region == 1)
            {
                landmarkGantry = MakeObject("Gantry trolley", GetMesh(name+"Gantry"), district.transform).transform;
                gantryClock = 0;
                TickLandmarks(0);
            }
            ShowLandmarkRoofs(false);
        }

        void ShowLandmarkRoofs(bool direct)
        {
            foreach (var roof in landmarkRoofs)
                if (roof && roof.activeSelf != direct) roof.SetActive(direct);
        }

        void TickLandmarks(float dt)
        {
            if (!landmarkGantry) return;
            gantryClock = Mathf.Repeat(gantryClock + dt*.19f, 2*Mathf.PI);
            landmarkGantry.localPosition = new Vector3(Mathf.Sin(gantryClock)*5.8f, 6.58f, -4.43f);
        }
    }
}
