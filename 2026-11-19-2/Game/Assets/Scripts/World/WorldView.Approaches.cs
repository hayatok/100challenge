using UnityEngine;

namespace Evac
{
    public sealed partial class WorldView
    {
        readonly GameObject[] approachRoofs = new GameObject[2];
        GameObject fieldShuttle,roadClosure,signalBeacon;
        Texture2D sunOcclusion;
        static readonly int Signal = Shader.PropertyToID("_FieldSignal");
        static readonly int SignalTint = Shader.PropertyToID("_FieldSignalTint");
        void BuildApproachBlocks(int route)
        {
            LoadSunOcclusion(route/2);
            fieldShuttle=null;
            roadClosure=null;
            signalBeacon=null;
            surface.SetVector(Signal,Vector4.zero);
            for (int i = 0; i < 2; i++)
            {
                string block = "approach" + (route / 2) + (i == 0 ? "North" : "South");
                MakeObject(block, GetMesh(block), district.transform);
                approachRoofs[i] = MakeObject(block + " roof", GetMesh(block + "Roof"), district.transform);
                approachRoofs[i].SetActive(false);
            }
        }
        void LoadSunOcclusion(int regionIndex)
        {
            if(sunOcclusion)ReleaseOwned(sunOcclusion);
            var asset=Resources.Load<TextAsset>("World/sun"+regionIndex);
            const int width=896,height=1792;
            bool packed=!SystemInfo.SupportsTextureFormat(TextureFormat.R16);
            sunOcclusion=new Texture2D(width,height,packed?TextureFormat.RGBA32:TextureFormat.R16,false,true){
                name="Static sun visibility",filterMode=FilterMode.Point,wrapMode=TextureWrapMode.Clamp
            };
            byte[] bytes=asset.bytes;
            if(packed)
            {
                var texels=new Color32[width*height];
                for(int i=0;i<texels.Length;i++)texels[i]=new Color32(bytes[2*i+1],bytes[2*i],0,255);
                sunOcclusion.SetPixels32(texels);
            }
            else sunOcclusion.LoadRawTextureData(bytes);
            sunOcclusion.Apply(false,true);
            surface.SetTexture("_SunOccluder",sunOcclusion);
            surface.SetFloat("_SunPacked",packed?1:0);
            Resources.UnloadAsset(asset);
        }
        public void SetSignalLight(Vector3 p,Color hue,float duration)
        {
            if(!surface)return;
            bool on=duration>0;
            if(!signalBeacon && on)signalBeacon=Place("fieldLamp",p);
            if(signalBeacon)
            {
                if(signalBeacon.activeSelf!=on)signalBeacon.SetActive(on);
                if(on)signalBeacon.transform.localPosition=p;
            }
            float intensity=on?Mathf.Min(1,duration)*(.91f+.09f*Mathf.Sin(duration*4)):0;
            surface.SetVector(Signal,new Vector4(p.x,p.y+.4f,p.z,intensity));
            surface.SetColor(SignalTint,hue);
        }
        public void DrawFleet(GameSim sim,float dt)
        {
            if(!fieldShuttle)
                fieldShuttle=MakeObject("Municipal shuttle",GetMesh("fieldShuttle"),district.transform);
            for(int bus=0;bus<2;bus++)
            {
                var vehicle=bus==0?transport.transform:fieldShuttle.transform;
                float heading=sim.FleetVehicleHeading(bus);
                vehicle.localPosition=ApproachBlocks.BusCenter(sim.FleetVehiclePosition(bus),bus,heading);
                // Blender vehicle fronts face negative Z.
                vehicle.localRotation=Quaternion.Euler(0,heading+180,0);
            }
            if(!roadClosure && sim.FleetDecisionPending)
                roadClosure=Place("threat",sim.FleetBlockPoint);
            if(roadClosure && roadClosure.activeSelf!=sim.FleetDecisionPending)
                roadClosure.SetActive(sim.FleetDecisionPending);
        }
        void ShowApproachRoofs(bool direct)
        {
            foreach (var roof in approachRoofs)
                if (roof && roof.activeSelf != direct) roof.SetActive(direct);
        }
    }
}
