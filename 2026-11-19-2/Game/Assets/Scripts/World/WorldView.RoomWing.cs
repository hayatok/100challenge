using System.Collections.Generic;
using UnityEngine;

namespace Evac
{
    internal static class RoomWingLayout
    {
        public static readonly Vector3 Entrance = new Vector3(0, 0, 92);

        [System.Serializable] sealed class Anchor
        {
            public float x, z;
        }

        [System.Serializable] sealed class Solid
        {
            public int region;
            public float x, z, width, depth, height;
        }

        [System.Serializable] sealed class Layout
        {
            public Anchor[] stations;
            public Solid[] solids;
        }

        static Layout layout;

        static Layout Measured
        {
            get
            {
                if (layout == null)
                {
                    var source = Resources.Load<TextAsset>("World/RoomWingLayout");
                    layout = JsonUtility.FromJson<Layout>(source.text);
                    Resources.UnloadAsset(source);
                }
                return layout;
            }
        }

        public static Vector3 Station(int index)
        {
            var anchor = Measured.stations[index];
            return new Vector3(anchor.x, 0, anchor.z);
        }

        public static IEnumerable<ApproachBlocks.Footprint> Solids(int mission)
        {
            int region = mission / 2;
            foreach (var solid in Measured.solids)
            {
                if (solid.region >= 0 && solid.region != region) continue;
                yield return new ApproachBlocks.Footprint {
                    x = solid.x, z = solid.z, width = solid.width, depth = solid.depth, height = solid.height
                };
            }
        }
    }

    public sealed partial class WorldView
    {
        static readonly int WingGateSignal = Shader.PropertyToID("_GateSignal");
        readonly Transform[] wingGatePanels = new Transform[2];
        readonly MeshRenderer[] wingGateLights = new MeshRenderer[2];
        readonly float[] wingGateSlides = new float[2];
        readonly bool[] wingGateOpen = new bool[2];
        Material roomWingMaterial;
        MaterialPropertyBlock wingGateSignal;
        GameObject roomWingRoof, wingFreight;

        void BuildRoomWing(int region)
        {
            if (!roomWingMaterial)
            {
                roomWingMaterial = new Material(Resources.Load<Shader>("World/RoomWing"));
                roomWingMaterial.SetTexture("_SurfaceScan", Resources.Load<Texture2D>("World/SurfaceScan"));
            }
            roomWingMaterial.SetFloat("_Wing", region);
            BindRoomLight(roomWingMaterial,region);
            string name = "roomWing" + region;
            BuildRoomMesh("Northern facility", name);
            roomWingRoof = BuildRoomMesh("Northern facility roof and upper walls", name + "Roof");
            wingFreight = null;
            if (region==3)
            {
                var serviceBus=BuildRoomMesh("Parked municipal service shuttle","fieldShuttle").transform;
                serviceBus.localPosition=new Vector3(9.64f,0,143.53f);
                serviceBus.localScale=Vector3.one*.72f;
            }
            for(int i=0;i<2;i++)
            {
                float x=i==0?-3.5f:3.5f;
                wingGatePanels[i]=BuildRoomMesh("Interior sliding door","roomWingGate").transform;
                wingGateSlides[i]=3.17f;
                wingGateOpen[i]=false;
                wingGatePanels[i].localPosition=new Vector3(x,0,120 + wingGateSlides[i]);
                var lamp=BuildRoomMesh("Interior door indicator","roomWingGateLamp");
                lamp.transform.localPosition=new Vector3(x,.99f,118.31f);
                wingGateLights[i]=lamp.GetComponent<MeshRenderer>();
            }
            SetWingGates(true,true,0);
            ShowRoomWingRoof(false);
        }

        GameObject BuildRoomMesh(string label, string resource)
        {
            var item = MakeObject(label, GetMesh(resource), district.transform);
            item.GetComponent<MeshRenderer>().sharedMaterial = roomWingMaterial;
            return item;
        }

        internal void SetWingGates(bool leftOpen, bool rightOpen, float dt)
        {
            for(int i=0;i<2;i++)
            {
                var panel=wingGatePanels[i];
                if(!panel)continue;
                bool open=i==0?leftOpen:rightOpen;
                if(open!=wingGateOpen[i])
                {
                    wingGateOpen[i]=open;
                    // The clear route opens on the authoritative navigation tick.
                    // Finish sliding the outside edge into the wall pocket afterward.
                    wingGateSlides[i]=open?Mathf.Max(wingGateSlides[i],2.12f):0;
                    wingGateSignal??=new MaterialPropertyBlock();
                    wingGateSignal.SetFloat(WingGateSignal,open?1:0);
                    wingGateLights[i].SetPropertyBlock(wingGateSignal);
                }
                wingGateSlides[i]=Mathf.MoveTowards(wingGateSlides[i],open?3.17f:0,Mathf.Max(0,dt)*3.8f);
                Vector3 anchor=panel.localPosition;
                anchor.z=120+wingGateSlides[i];
                panel.localPosition=anchor;
            }
        }

        internal void SetWingFreight(Vector3 position, bool visible)
        {
            if(!district)return;
            if(visible && !wingFreight)
            {
                string name=region==0?"roomWingOxygen":region==1?"roomWingHandTruck":
                            region==3?"roomWingTow":null;
                if(name!=null)wingFreight=BuildRoomMesh("Movable evacuation equipment",name);
            }
            if(!wingFreight)return;
            if(wingFreight.activeSelf!=visible)wingFreight.SetActive(visible);
            if(visible)wingFreight.transform.localPosition=position;
        }

        void ShowRoomWingRoof(bool direct)
        {
            if (roomWingRoof && roomWingRoof.activeSelf != direct) roomWingRoof.SetActive(direct);
        }
    }
}
