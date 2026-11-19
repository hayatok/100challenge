using System;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
using UnityEngine.Rendering;

namespace Evac
{
    /// <summary>Meshes baked in Blender share a palette and one instanced surface shader.</summary>
    public sealed partial class WorldView : MonoBehaviour
    {
        const int CrowdBatchLimit = 100;

        sealed class CrowdBatch
        {
            public Mesh mesh;
            public readonly List<Matrix4x4> transforms = new List<Matrix4x4>(160);
            public readonly List<Vector4> poses = new List<Vector4>(160);
            public readonly List<Vector4> forms = new List<Vector4>(160);
            public readonly List<Vector4> left = new List<Vector4>(CrowdBatchLimit);
            public readonly List<Vector4> right = new List<Vector4>(CrowdBatchLimit);
            public readonly List<Vector4> aid = new List<Vector4>(CrowdBatchLimit);
            public readonly MaterialPropertyBlock properties = new MaterialPropertyBlock();
        }

        struct Motion
        {
            public float phase, health, impact, stride, action, fall;
            public Vector3 fallDirection, contactRoot;
            public ActorGait.Foot left, right;
            public bool tracking, hasLanding;
            public Vector4 floorProfile;
            public float landingHeight, shadowHeight;
            public MarketCastPose.Transition market;
        }

        readonly Dictionary<int, Motion> motions = new Dictionary<int, Motion>();
        readonly Dictionary<string, Mesh> meshes = new Dictionary<string, Mesh>();
        readonly Dictionary<int, CrowdBatch> batches = new Dictionary<int, CrowdBatch>();
        readonly List<Matrix4x4> shadows = new List<Matrix4x4>(200);
        readonly Dictionary<int, Transform> markers = new Dictionary<int, Transform>();
        static readonly int Pose = Shader.PropertyToID("_Pose");
        static readonly int Form = Shader.PropertyToID("_Form");
        static readonly int PlantLeft = Shader.PropertyToID("_PlantLeft");
        static readonly int PlantRight = Shader.PropertyToID("_PlantRight");
        static readonly int AidPosition = Shader.PropertyToID("_AidPosition");
        Material surface, shadowMaterial, skyMaterial, waterMaterial;
        readonly MeshFilter[] signalLamps = new MeshFilter[3];
        float waterClock;
        GameObject district, equipment, transport, stationRoof;
        Camera playerCamera;
        MeshFilter equipmentMesh;
        MeshRenderer equipmentRenderer;
        MaterialPropertyBlock equipmentState;
        int handActivity;
        Mesh shadow;
        Texture2D bakedLight;
        Vector3 transportOrigin;
        int region, builtSite, submissionFrame = -1;
        bool writingActors, overviewCrowd;
        Vector3 crowdCameraPosition;
        float nearActorDistanceSquared;
        GameObject siteModel, flood, gate, supply, generator, crates, foundation, requestProp;
        GameObject alarmFixture;
        MeshFilter alarmLens;
        int alarmDistrict = -1;
        bool alarmOn;
        int requestType, displayedPower = -1, displayedPassengers = -1;
        readonly List<GameObject> passengers = new List<GameObject>();
        // Bench centers in art-source/city_bus.py, offset toward the front of each seat back.
        static readonly float[] busPassengerRows = { -1.00f, .20f, 1.40f, 2.60f, 3.69f };
        Vector3 constructionSpot;

        public void Build(int missionIndex)
        {
            if (!surface)
            {
                surface = new Material(Resources.Load<Shader>("World/StreetSurface")) { enableInstancing = true };
                if (Application.isMobilePlatform || SystemInfo.graphicsMemorySize < 1536)
                    surface.EnableKeyword("EVAC_MOBILE");
                equipmentState = new MaterialPropertyBlock();
                shadowMaterial = new Material(Resources.Load<Shader>("World/StreetShadow")) { enableInstancing = true };
                waterMaterial = new Material(Resources.Load<Shader>("World/PlatformWater"));
                skyMaterial = new Material(Resources.Load<Shader>("World/CoastalSky"));
                skyMaterial.SetTexture("_Plate", Resources.Load<Texture2D>("World/CoastalPlate"));
                surface.SetTexture("_SurfaceScan",Resources.Load<Texture2D>("World/SurfaceScan"));
                surface.SetTexture("_FieldFaces",Resources.Load<Texture2D>("World/FieldFaces"));
                surface.SetTexture("_Materials",Resources.Load<Texture2D>("World/MossMaterials"));
                surface.SetTexture("_ShopFronts",Resources.Load<Texture2D>("World/MarketFronts"));
                surface.SetTexture("_DepotFronts",Resources.Load<Texture2D>("World/DepotFronts"));
                shadow = MakeShadow();
            }
            if (district) { district.SetActive(false); ReleaseOwned(district); }
            if (equipment) { equipment.SetActive(false); ReleaseOwned(equipment); }
            markers.Clear();
            batches.Clear();
            shadows.Clear();
            motions.Clear();
            writingActors = false;
            submissionFrame = -1;

            int route = Mathf.Clamp(missionIndex, 0, RoutePlan.All.Length - 1);
            region = route / 2;
            if (bakedLight) ReleaseOwned(bakedLight);
            var lightData = Resources.Load<TextAsset>("World/light" + region);
            bakedLight = new Texture2D(192,320,TextureFormat.R8,false,true) {
                name = "Baked street light", wrapMode = TextureWrapMode.Clamp, filterMode = FilterMode.Bilinear
            };
            bakedLight.LoadRawTextureData(lightData.bytes);
            bakedLight.Apply(false,true);
            Resources.UnloadAsset(lightData);
            surface.SetTexture("_StreetLight", bakedLight);
            district = MakeObject("District scenery", GetMesh("district" + region), transform);
            surface.SetFloat("_Station",region == 2 ? 1 : 0);
            surface.SetFloat("_WorldDistrict",region);
            stationRoof = region==2 ? MakeObject("Station roof",GetMesh("stationRoof"),district.transform):null;
            if (stationRoof) stationRoof.SetActive(false);
            var exit = RoutePlan.All[route].exit;
            transport = new GameObject("Evacuation transport");
            transport.transform.SetParent(district.transform, false);

            transportOrigin = WorldGeometry.VehicleOrigin(exit);
            transport.transform.localPosition = transportOrigin;
            if (region == 2)
            {
                for (int car = -1; car < 4; car++)
                {
                    var carriage = MakeObject("Carriage", GetMesh("train"), transport.transform);
                    carriage.transform.localPosition = new Vector3(0, 0, car * 13.5f);
                }
            }
            else MakeObject("Evacuation bus", GetMesh("bus"), transport.transform);
            equipment = MakeObject("First person equipment", GetMesh("hands"), transform);
            equipmentMesh = equipment.GetComponent<MeshFilter>();
            handActivity = 0;
            equipmentRenderer = equipment.GetComponent<MeshRenderer>();
            equipmentState.SetVector(Form,new Vector4(4,0,0,0));
            equipmentRenderer.SetPropertyBlock(equipmentState);
            equipment.SetActive(false);
            playerCamera = Camera.main;
            float evening = route == 1 || route == 3 || route == 5 ? 1 : route == 7 ? .45f : .06f;
            skyMaterial.SetFloat("_Evening", evening);
            surface.SetFloat("_Evening", evening);
            RenderSettings.skybox = skyMaterial;
            if (playerCamera) playerCamera.clearFlags = CameraClearFlags.Skybox;
            var plan = RoutePlan.All[route];
            constructionSpot = WorldGeometry.SitePosition(plan.depot);
            foundation = Place("foundation", constructionSpot);
            supply = Place("depot", plan.depot + Vector3.right * 1.85f);
            generator = Place("works", WorldGeometry.UtilityPosition(plan.works, false));
            crates = Place("cache", WorldGeometry.UtilityPosition(plan.cache, true));
            gate = Place("threat", plan.gate);
            builtSite = 0;
            siteModel = null;
            requestProp = null;
            requestType = 0;
            displayedPower = displayedPassengers = -1;
            passengers.Clear();
            flood = null;
            alarmFixture = null;
            alarmLens = null;
            alarmDistrict = -1;
            if (region == 2)
            {
                flood = Place("water", plan.assembly);
                flood.GetComponent<MeshRenderer>().sharedMaterial = waterMaterial;
                waterClock = 0;
                for(int i=0;i<3;i++)
                {
                    Transform parent = i==0 ? generator.transform : i==1 ? district.transform : gate.transform;
                    var lamp = MakeObject("Circuit lamp",GetMesh("signalOff"),parent);
                    lamp.transform.localPosition = i==0 ? new Vector3(.45f,1.56f,0) :
                        i==1 ? new Vector3(-8.18f,2.07f,18.62f) : new Vector3(1.38f,1.28f,0);
                    signalLamps[i]=lamp.GetComponent<MeshFilter>();
                }
            }
            BuildApproachBlocks(route);
            BuildLandmarks(route);
            BuildRoomWing(region);
            BuildRefuges(route);
            IndexActorFloor();
        }

        GameObject Place(string asset, Vector3 position)
        {
            var item = MakeObject(asset, GetMesh(asset), district.transform);
            item.transform.localPosition = position;
            return item;
        }

        public void SetAlarm(Vector3 point,int district,bool active)
        {
            if (!this.district) return;
            int kind=Mathf.Clamp(district,0,3);
            if (!alarmFixture || kind != alarmDistrict)
            {
                if (alarmFixture) ReleaseOwned(alarmFixture);
                alarmFixture=Place("alarm"+kind,point);
                var lamp=MakeObject("Alarm indicator",GetMesh(active?"signalOn":"signalOff"),alarmFixture.transform);
                float height=kind==0?1.92f:kind==1?1.58f:kind==2?2.97f:2.17f;
                lamp.transform.localPosition=Vector3.up*height;
                lamp.transform.localScale=new Vector3(1.08f,.83f,1.08f);
                alarmLens=lamp.GetComponent<MeshFilter>();
                alarmDistrict=kind;
                alarmOn=active;
            }
            if (alarmOn != active)
            {
                alarmLens.sharedMesh=GetMesh(active?"signalOn":"signalOff");
                alarmOn=active;
            }
            Vector3 stand=point+new Vector3(.43f,0,.19f);
            if(alarmFixture.transform.localPosition!=stand)alarmFixture.transform.localPosition=stand;
        }

        public void SetRequestProp(int type, Vector3 position)
        {
            if (!district) return;
            type = Mathf.Clamp(type,0,2);
            if (type != requestType)
            {
                if (requestProp) { requestProp.SetActive(false); ReleaseOwned(requestProp); }
                requestProp = type == 0 ? null : Place(type == 1 ? "cache" : "works",position);
                if (requestProp) requestProp.transform.localScale = Vector3.one * (type == 1 ? .38f : .59f);
                requestType = type;
            }
            if (requestProp) requestProp.transform.localPosition = position + new Vector3(.66f,0,.26f);
        }

        public void SetFieldState(int site, float construction, int boarded, int powerMask, float water, bool passageOpen)
        {
            if (!district) return;
            TickLandmarks(Mathf.Min(Time.deltaTime,.1f));
            if(region==3) { waterClock += Mathf.Min(Time.deltaTime,.1f); surface.SetFloat("_WetTime",waterClock); }
            if (site != builtSite)
            {
                if (siteModel) ReleaseOwned(siteModel);
                siteModel = site == 0 ? null : Place(site == 1 ? "tent" : "workshop", constructionSpot);
                builtSite = site;
            }
            if (siteModel) siteModel.transform.localScale = new Vector3(1, Mathf.Lerp(.18f, 1, construction), 1);
            if (gate) gate.transform.localScale = new Vector3(1,passageOpen ? .52f : 1,1);
            if (flood)
            {
                waterClock += Mathf.Min(Time.deltaTime,.1f);
                waterMaterial.SetFloat("_RippleClock",waterClock);
                if (displayedPower != powerMask)
                {
                    for(int i=0;i<3;i++) signalLamps[i].sharedMesh = GetMesh((powerMask & (1<<i))!=0 ? "signalOn" : "signalOff");
                    displayedPower = powerMask;
                }
                float level = Mathf.Clamp01(water);
                flood.SetActive(level > .025f);
                flood.transform.localScale = new Vector3(1.4f + level*4.1f,1,1.5f + level*5.8f);
            }
            int seats = region == 2 ? 64 : busPassengerRows.Length * 4;
            int count = Mathf.Clamp(boarded, 0, seats);
            if (count == displayedPassengers) return;
            displayedPassengers = count;
            while (passengers.Count < count)
            {
                int n = passengers.Count;
                float side = n % 2 == 0 ? -1 : 1;
                var rider = MakeObject("Evacuee", GetMesh("passenger"), transport.transform);
                if (region == 2)
                {
                    int slot = n / 2 % 8;
                    int car = n / 16;
                    float z = -6.5f + .88f + slot*1.52f + car*13.5f;
                    rider.transform.localPosition = new Vector3(side*1.503f,1.77f,z);
                    rider.transform.localScale = new Vector3(.19f,1,1);
                }
                else
                {
                    // Alternate sides, then fill the second seat on each bench.
                    float seatX = n % 4 < 2 ? 1.15f : .76f;
                    rider.transform.localPosition = new Vector3(side*seatX,1.30f,busPassengerRows[n/4]);
                    rider.transform.localScale = new Vector3(.9f,1,1);
                }
                passengers.Add(rider);
            }
            for (int i = 0; i < passengers.Count; i++)
                if (passengers[i].activeSelf != (i < count)) passengers[i].SetActive(i<count);
        }

        public void SetDeparture(float progress)
        {
            if (transport)
                transport.transform.localPosition = transportOrigin + Vector3.back * (42 * progress * progress);
        }

        public void DrawStretcherPatient(int id,int variant,Vector3 patientPosition,float carrierYaw)
        {
            DrawActor(id,2,variant,patientPosition,carrierYaw,0,.59f,false,false,0,5);
        }

        public void DrawActor(int id, int kind, int variant, Vector3 position, float yaw,
                              float speed, float hp01, bool acting, bool possessed, float dt, int activity = 0,
                              Vector3 hitDirection = default, Vector3? companionPosition = null, float companionYaw = 0,
                              MarketCastPose market = default)
        {
            if (!district) return;
            BeginActors();
            kind = Mathf.Clamp(kind, 0, 2);
            variant = (variant & int.MaxValue) % (kind == 0 ? 4 : kind == 2 ? 6 : 4);
            if (!motions.TryGetValue(id, out var m))
                m = new Motion { phase = (id & 255) * 2.391f, health = hp01, fall = hp01<=0 ? 1 : 0 };
            m.impact = Mathf.Max(Mathf.MoveTowards(m.impact, 0, dt * 3.2f), Mathf.Clamp01((m.health - hp01) * 8));
            if (hitDirection.sqrMagnitude>.0001f && (m.health>0 || m.fallDirection.sqrMagnitude<.01f))
                m.fallDirection = new Vector3(hitDirection.x,0,hitDirection.z).normalized;
            if (hp01<=0)
            {
                if (m.fallDirection.sqrMagnitude<.01f) m.fallDirection = Quaternion.Euler(0,yaw,0)*Vector3.back;
                m.fall = Mathf.MoveTowards(m.fall,1,dt/.57f);
            }
            else {m.fall=0;m.hasLanding=false;}
            m.health = hp01;
            m.stride = Mathf.MoveTowards(m.stride, Mathf.Clamp01(speed / 3.6f), dt * 6);
            m.action = kind == 0 && activity == 4 ? 1 :
                Mathf.MoveTowards(m.action, acting ? 1 : 0, dt * (kind == 0 ? 7 : 5));
            bool far = overviewCrowd || (position-crowdCameraPosition).sqrMagnitude > nearActorDistanceSquared;
            if (hp01>0)
            {
                float stepLength=Mathf.Lerp(.98f,1.95f,Mathf.SmoothStep(0,1,Mathf.InverseLerp(.58f,.96f,m.stride)));
                float angularSpeed=2*Mathf.PI*Mathf.Max(0,speed)/stepLength;
                if(far)angularSpeed=Mathf.Max(.8f,angularSpeed);
                else if(speed<.105f)angularSpeed=1.12f;
                m.phase = Mathf.Repeat(m.phase + dt*angularSpeed, Mathf.PI*2);
            }
            Vector4 marketPose=market.Blend(kind,dt,ref m.market);
            // Followers can share a waypoint with the camera carrier. Keep their head and
            // upper torso out of the eye point while their simulation continues normally.
            Vector3 eyeOffset = crowdCameraPosition - position;
            bool overlapsEye = kind != 1 && activity != 5 && hp01 > 0 && playerCamera &&
                !playerCamera.orthographic && eyeOffset.y > .85f && eyeOffset.y < 2.05f &&
                eyeOffset.x * eyeOffset.x + eyeOffset.z * eyeOffset.z < .45f * .45f;
            if (possessed || overlapsEye)
            {
                m.tracking=false;
                motions[id]=m;
                return;
            }

            int key = kind * 8 + variant + (far ? 32 : 0);
            CrowdBatch batch;
            while (batches.TryGetValue(key,out batch) && batch.transforms.Count>=CrowdBatchLimit)
                key+=64;
            if (batch==null)
            {
                batch = new CrowdBatch { mesh = GetMesh((far ? "actorFar" : "actor") + kind + "_" + variant) };
                batches.Add(key, batch);
            }
            float stature = .92f + ((id & 31) % 8) * .022f;
            float girth = .93f + ((id & 63) % 7) * .027f;
            if (kind == 1 && variant == 2) { girth *= 1.24f; stature *= 1.09f; }
            else if (kind == 1 && variant == 1) { girth *= .89f; stature *= .96f; }
            var rotation = Quaternion.Euler(0, yaw, 0);
            bool onStretcher=activity==5;
            float lift=position.y;
            float surfaceHeight=onStretcher?0:m.hasLanding?m.landingHeight:ActorFloor(position);
            position.y+=surfaceHeight;
            if(onStretcher)
            {
                position+=Vector3.up*(.76f+.146f*girth)+rotation*Vector3.forward*(.87f*stature+.052f);
                rotation*=Quaternion.Euler(-90,0,0);
            }
            if (hp01 <= 0)
            {
                float angle=FallAngle(m.fall);
                float settleFacing=Mathf.SmoothStep(0,1,Mathf.InverseLerp(.16f,.84f,m.fall));
                float faceUp=Vector3.Dot(rotation*Vector3.forward,m.fallDirection)<=0?1:-1;
                rotation=Quaternion.Slerp(rotation,Quaternion.LookRotation(-faceUp*m.fallDirection),settleFacing);
                position.y=Mathf.Lerp(position.y,surfaceHeight,settleFacing);
                rotation = Quaternion.AngleAxis(angle,Vector3.Cross(Vector3.up,m.fallDirection)) * rotation;
            }
            var scale = new Vector3(girth,stature,girth);
            float limp=kind==2 && activity==1 ? 1 :
                ActorGait.Smooth(.24f,.66f,1-hp01)*(kind==1?.66f:1);
            if(kind==1)limp=Mathf.Max(limp,variant==1?.20f:variant==2?.31f:.52f);
            int planted=0;
            Vector4 left=default,right=default,aid=default;
            bool encounterStance=kind==1 && marketPose.w>1.5f && (marketPose.x>0 || marketPose.z>0);
            bool tracking=!far && hp01>0 && lift<.09f && dt>0 && !encounterStance;
            if(tracking)
            {
                if(!m.tracking || (position-m.contactRoot).sqrMagnitude>.8f)
                {
                    m.left=default;
                    m.right=default;
                }
                if(ActorGait.Solve(m.phase,m.stride,limp,0,position,rotation,scale,dt,ref m.left,out left))planted|=1;
                if(ActorGait.Solve(m.phase,m.stride,limp,1,position,rotation,scale,dt,ref m.right,out right))planted|=2;
            }
            if(hp01<=0)
            {
                // Both foot-plant slots are free once the actor falls.
                float faceUp=Vector3.Dot(Quaternion.Euler(0,yaw,0)*Vector3.forward,m.fallDirection)<=0?1:-1;
                left=new Vector4(faceUp,(id&1)==0?1:-1,0,0);
                if(!m.hasLanding)
                {
                    Vector3 span=m.fallDirection*stature;
                    m.landingHeight=surfaceHeight;
                    m.shadowHeight=ActorFloor(position+span*.78f);
                    Vector3 across=Vector3.Cross(Vector3.up,m.fallDirection)*girth;
                    // The infected neck and skull lean to one side of the jacket.
                    // Probe under the skull so a narrow centre stripe cannot prop it up.
                    float headSide=kind==1?(variant%2==0?-.11f:.09f):0;
                    Vector3 head=position+span*1.70f-across*(faceUp*headSide);
                    m.floorProfile=(new Vector4(
                        BodySupport(position+span*.10f,span*.12f,across*.21f),
                        BodySupport(position+span*.60f,span*.23f,across*.18f),
                        BodySupport(position+span*1.20f,span*.28f,across*.21f),
                        ActorFloor(head))
                        -Vector4.one*surfaceHeight)/girth;
                    m.hasLanding=true;
                }
                right=m.floorProfile;
            }
            if(!far && hp01>0 && activity==1 && companionPosition.HasValue)
                aid=SupportAnchor(position,rotation,scale,kind,companionPosition.Value+Vector3.up*ActorFloor(companionPosition.Value),companionYaw);
            if(activity==0 || activity==4)aid=marketPose;
            m.contactRoot=position;
            m.tracking=tracking;
            motions[id]=m;
            batch.transforms.Add(Matrix4x4.TRS(position, rotation, scale));
            batch.poses.Add(new Vector4(m.phase, m.stride, onStretcher?Time.time:m.action, m.impact));
            batch.forms.Add(new Vector4(kind + 1, activity, planted+limp*.25f, m.fall));
            batch.left.Add(left);
            batch.right.Add(right);
            batch.aid.Add(aid);
            if(onStretcher)return;
            float grounded = Mathf.SmoothStep(0,1,Mathf.InverseLerp(.21f,.85f,m.fall));
            Vector3 offset = Vector3.Lerp(new Vector3(.26f,0,.19f),m.fallDirection*(.78f*stature),grounded);
            Vector3 shadowPosition = position+offset;
            shadowPosition.y=(grounded>=1?m.shadowHeight:ActorFloor(shadowPosition))+.014f;
            float directionAngle = Mathf.Atan2(m.fallDirection.x,m.fallDirection.z)*Mathf.Rad2Deg;
            shadows.Add(Matrix4x4.TRS(shadowPosition,Quaternion.Euler(0,Mathf.LerpAngle(54,directionAngle,grounded),0),
                new Vector3(girth*Mathf.Lerp(.47f,.40f,grounded),1,Mathf.Lerp(.98f,stature,grounded))));
        }

        static Vector4 SupportAnchor(Vector3 position,Quaternion rotation,Vector3 scale,int kind,
                                     Vector3 other,float otherYaw)
        {
            Vector3 gap=other-position;
            gap.y=0;
            float distance=gap.magnitude;
            float weight=(1-ActorGait.Smooth(.79f,1.14f,distance))*ActorGait.Smooth(.10f,.26f,distance);
            if(weight<=.001f)return Vector4.zero;
            Quaternion otherFacing=Quaternion.Euler(0,otherYaw,0);
            Vector3 shoulderSide=otherFacing*Vector3.right;
            float inward=Vector3.Dot(-gap,shoulderSide)<0?-1:1;
            Vector3 shoulder=other+shoulderSide*(.173f*inward)+
                otherFacing*Vector3.forward*.024f+Vector3.up*(kind==0?1.36f:1.40f);
            Vector3 anchor=Quaternion.Inverse(rotation)*(shoulder-position);
            float arm=anchor.x<0?-1:1;
            return new Vector4(anchor.x/scale.x,anchor.y/scale.y,anchor.z/scale.z,arm*weight);
        }

        static readonly float[] FallTimes = { 0,.18f,.4f,.64f,.79f,.9f,1 };
        static readonly float[] FallAngles = { 0,9,37,74,88,86,90 };
        static float FallAngle(float t)
        {
            for(int i=1;i<FallTimes.Length;i++)
                if(t<=FallTimes[i]) return Mathf.SmoothStep(FallAngles[i-1],FallAngles[i],Mathf.InverseLerp(FallTimes[i-1],FallTimes[i],t));
            return 90;
        }

        void BeginActors()
        {
            if (writingActors) return;
            writingActors = true;
            overviewCrowd = playerCamera && playerCamera.orthographic && playerCamera.orthographicSize >= 9f;
            crowdCameraPosition = playerCamera ? playerCamera.transform.position : Vector3.zero;
            nearActorDistanceSquared = !playerCamera || playerCamera.orthographic ? float.PositiveInfinity :
                (Application.isMobilePlatform ? 81f : 169f);
            foreach (var batch in batches.Values)
            {
                batch.transforms.Clear();
                batch.poses.Clear();
                batch.forms.Clear();
                batch.left.Clear();
                batch.right.Clear();
                batch.aid.Clear();
            }
            shadows.Clear();
        }

        public void EndFrame()
        {
            if (!surface) return;
            BeginActors();
            writingActors = false;
            submissionFrame = Time.frameCount;
            RenderActors();
        }

        void LateUpdate()
        {
            if (district && submissionFrame >= 0 && submissionFrame != Time.frameCount)
                RenderActors();
        }

        void RenderActors()
        {
            foreach (var batch in batches.Values)
            {
                if (batch.transforms.Count == 0) continue;
                if (SystemInfo.supportsInstancing)
                {
                    batch.properties.Clear();
                    batch.properties.SetVectorArray(Pose, batch.poses);
                    batch.properties.SetVectorArray(Form, batch.forms);
                    batch.properties.SetVectorArray(PlantLeft, batch.left);
                    batch.properties.SetVectorArray(PlantRight, batch.right);
                    batch.properties.SetVectorArray(AidPosition, batch.aid);
                    Graphics.DrawMeshInstanced(batch.mesh, 0, surface, batch.transforms, batch.properties,
                        ShadowCastingMode.Off, false);
                }
                else
                {
                    for (int i = 0; i < batch.transforms.Count; i++)
                    {
                        batch.properties.Clear();
                        batch.properties.SetVector(Pose, batch.poses[i]);
                        batch.properties.SetVector(Form, batch.forms[i]);
                        batch.properties.SetVector(PlantLeft, batch.left[i]);
                        batch.properties.SetVector(PlantRight, batch.right[i]);
                        batch.properties.SetVector(AidPosition, batch.aid[i]);
                        Graphics.DrawMesh(batch.mesh, batch.transforms[i], surface, 0, null, 0, batch.properties);
                    }
                }
            }
            if (shadows.Count > 0 && SystemInfo.supportsInstancing)
                Graphics.DrawMeshInstanced(shadow, 0, shadowMaterial, shadows, null, ShadowCastingMode.Off, false);
        }

        public void DrawFirstPerson(bool visible,float motion,float recoil,float reload01,float time,int activity = 0,float aim01 = 0,bool handsOnStretcher = false)
        {
            if (!equipment) return;
            if (!playerCamera) playerCamera = Camera.main;
            visible &= playerCamera != null;
            ShowApproachRoofs(visible);
            ShowLandmarkRoofs(visible);
            ShowRoomWingRoof(visible);
            if (stationRoof && stationRoof.activeSelf!=visible) stationRoof.SetActive(visible);
            bool showEquipment=visible && !handsOnStretcher;
            if (equipment.activeSelf!=showEquipment) equipment.SetActive(showEquipment);
            if (!showEquipment)return;
            int pose = activity >= 1 && activity <= 3 ? activity : 0;
            if (pose != handActivity)
            {
                handActivity = pose;
                equipmentMesh.sharedMesh = GetMesh(pose == 3 ? "handsCargo" : pose == 0 ? "hands" : "handsHelping");
            }
            var rig = equipment.transform;
            if (rig.parent != playerCamera.transform) rig.SetParent(playerCamera.transform, false);
            float bob = Mathf.Clamp01(motion);
            float dip = Mathf.Sin(Mathf.Clamp01(reload01) * Mathf.PI);
            equipmentState.SetVector(Pose,new Vector4(reload01,recoil,time,bob));
            equipmentState.SetVector(Form,new Vector4(4,pose,0,0));
            equipmentRenderer.SetPropertyBlock(equipmentState);
            float aim = pose == 0 && reload01 <= 0 ? Mathf.SmoothStep(0,1,Mathf.Clamp01(aim01)) : 0;
            var hip = new Vector3(.065f + .012f*Mathf.Sin(time*8)*bob - dip*.043f,
                -.094f + .012f*Mathf.Abs(Mathf.Sin(time*8))*bob + dip*.050f, .145f - recoil*.045f + dip*.023f);
            // The aperture center lies at (.122,-.007) in the Blender equipment mesh.
            // Align its axis with the view and bring the frame closer as the arms rise.
            var sight = new Vector3(-.122f,.007f,-.072f-recoil*.019f);
            float arc = 4*aim*(1-aim);
            rig.localPosition = Vector3.Lerp(hip,sight,aim) + new Vector3(0,-.019f, .018f)*arc;
            var hipAngles = new Vector3(-recoil*9 - dip*4,-3+dip*20,dip*28);
            var sightAngles = new Vector3(-recoil*1.65f,0,0);
            rig.localRotation = Quaternion.Euler(Vector3.Lerp(hipAngles,sightAngles,aim) + Vector3.forward*(arc*2.8f));
        }

        public void SetObjective(string label,Vector3 position,int index,bool active)
        {
            if (!district) return;
            switch (index)
            {
                case 0:
                    if (flood) flood.transform.localPosition = position;
                    break;
                case 1: gate.transform.localPosition = position; break;
                case 2:
                    transportOrigin = WorldGeometry.VehicleOrigin(position);
                    transport.transform.localPosition = transportOrigin;
                    break;
                case 3:
                    supply.transform.localPosition = position + Vector3.right * 1.85f;
                    constructionSpot = WorldGeometry.SitePosition(position);
                    foundation.transform.localPosition = constructionSpot;
                    if (siteModel) siteModel.transform.localPosition = constructionSpot;
                    break;
                case 4: generator.transform.localPosition = WorldGeometry.UtilityPosition(position,false); break;
                case 5: crates.transform.localPosition = WorldGeometry.UtilityPosition(position,true); break;
            }
            if (!markers.TryGetValue(index, out var marker))
            {
                if (!active) return;
                string name = "Objective " + index;
                var mesh = MakeMarker(index);
                meshes[name] = mesh;
                marker = MakeObject(name, mesh, district.transform).transform;
                markers[index] = marker;
            }
            marker.gameObject.SetActive(active);
            marker.name = label;
            marker.localPosition = position + Vector3.up * .083f;
        }

        GameObject MakeObject(string label, Mesh mesh, Transform owner)
        {
            var item = new GameObject(label);
            item.transform.SetParent(owner, false);
            item.AddComponent<MeshFilter>().sharedMesh = mesh;
            var renderer = item.AddComponent<MeshRenderer>();
            renderer.sharedMaterial = surface;
            renderer.shadowCastingMode = ShadowCastingMode.Off;
            renderer.receiveShadows = false;
            return item;
        }

        Mesh GetMesh(string name)
        {
            if (meshes.TryGetValue(name, out var result)) return result;
            TextAsset data = Resources.Load<TextAsset>("World/" + name);
            using (var reader = new BinaryReader(new MemoryStream(data.bytes, false)))
            {
                int count = reader.ReadInt32();
                var vertices = new Vector3[count];
                var colors = new Color32[count];
                var normals = new Vector3[count];
                var joints = new Vector2[count];
                var indices = new int[count];
                var artwork = new Vector2[count];
                bool hasArtwork = reader.BaseStream.Length == 4L + count*23L;
                // Actor exports contain one record per triangle corner. Share only identical
                // corners so indexed drawing can reuse the animated vertex shader's results.
                var actorVertices = name.StartsWith("actor",StringComparison.Ordinal)
                    ? new Dictionary<(Vector3 position, int normal, int style, uint uv),int>(count/4)
                    : null;
                int vertexCount = 0;
                for (int i = 0; i < count; i++)
                {
                    var position = new Vector3(reader.ReadSingle(), reader.ReadSingle(), reader.ReadSingle());
                    sbyte nx = reader.ReadSByte(), ny = reader.ReadSByte(), nz = reader.ReadSByte();
                    byte red = reader.ReadByte(), green = reader.ReadByte(), blue = reader.ReadByte();
                    int packed = reader.ReadByte();
                    ushort u = hasArtwork ? reader.ReadUInt16() : (ushort)0;
                    ushort v = hasArtwork ? reader.ReadUInt16() : (ushort)0;
                    if (actorVertices != null)
                    {
                        int normal = (nx & 255) | ((ny & 255) << 8) | ((nz & 255) << 16);
                        int style = red | (green << 8) | (blue << 16) | (packed << 24);
                        var key = (position, normal, style, (uint)u | ((uint)v << 16));
                        if (actorVertices.TryGetValue(key,out indices[i])) continue;
                        actorVertices.Add(key,vertexCount);
                    }
                    indices[i] = vertexCount;
                    vertices[vertexCount] = position;
                    normals[vertexCount] = new Vector3(nx,ny,nz) / 126f;
                    colors[vertexCount] = new Color32(red,green,blue,255);
                    joints[vertexCount] = new Vector2(packed % 16, packed / 16);
                    artwork[vertexCount] = new Vector2(u/65535f,v/65535f);
                    vertexCount++;
                }
                result = new Mesh { name = name, indexFormat = vertexCount > 65535 ? IndexFormat.UInt32 : IndexFormat.UInt16 };
                result.SetVertices(vertices,0,vertexCount);
                result.SetColors(colors,0,vertexCount);
                result.SetNormals(normals,0,vertexCount);
                result.SetUVs(0,joints,0,vertexCount);
                result.SetUVs(1,artwork,0,vertexCount);
                result.triangles = indices;
                RememberActorFloor(name,vertices);
                result.UploadMeshData(true);
            }
            Resources.UnloadAsset(data);
            meshes.Add(name, result);
            return result;
        }

        Mesh MakeMarker(int index)
        {
            string key = "Objective " + index;
            if (meshes.TryGetValue(key, out var existing)) return existing;
            var vertices = new List<Vector3>();
            var colors = new List<Color32>();
            var triangles = new List<int>();
            Color32 orange = new Color32(235,166,63,255), mint = new Color32(111,195,171,255);
            for (int band=0; band<2; band++)
            {
                for (int i=0;i<48;i++)
                {
                    if (band == 0 && i % 12 < 2) continue;
                    float a=i*Mathf.PI/24, b=(i+1)*Mathf.PI/24;
                    float r=band==0?1.36f:.99f, t=band==0?.105f:.047f;
                    int n=vertices.Count;
                    vertices.Add(new Vector3(Mathf.Sin(a)*r,0,Mathf.Cos(a)*r));
                    vertices.Add(new Vector3(Mathf.Sin(b)*r,0,Mathf.Cos(b)*r));
                    vertices.Add(new Vector3(Mathf.Sin(a)*(r-t),0,Mathf.Cos(a)*(r-t)));
                    vertices.Add(new Vector3(Mathf.Sin(b)*(r-t),0,Mathf.Cos(b)*(r-t)));
                    for(int k=0;k<4;k++) colors.Add(index==2||index==4?orange:mint);
                    triangles.AddRange(new[]{n,n+1,n+2,n+2,n+1,n+3});
                }
            }
            var mesh = new Mesh { name = key };
            mesh.SetVertices(vertices); mesh.SetColors(colors); mesh.SetTriangles(triangles,0);
            return mesh;
        }

        static Mesh MakeShadow()
        {
            var mesh = new Mesh {name="Foot contact"};
            mesh.vertices = new[]{new Vector3(-1,0,-1),new Vector3(-1,0,1),new Vector3(1,0,1),new Vector3(1,0,-1)};
            mesh.uv = new[]{Vector2.zero,Vector2.up,Vector2.one,Vector2.right};
            mesh.triangles = new[]{0,1,2,0,2,3};
            return mesh;
        }

        static void ReleaseOwned(UnityEngine.Object item)
        {
            if (Application.isPlaying) Destroy(item);
            else DestroyImmediate(item);
        }

        void OnDestroy()
        {
            if(equipment) ReleaseOwned(equipment);
            foreach (var mesh in meshes.Values) ReleaseOwned(mesh);
            if(shadow) ReleaseOwned(shadow);
            ReleaseIncidentResources();
            if(bakedLight) ReleaseOwned(bakedLight);
            if(sunOcclusion) ReleaseOwned(sunOcclusion);
            if(surface) ReleaseOwned(surface);
            if(shadowMaterial) ReleaseOwned(shadowMaterial);
            if(skyMaterial) ReleaseOwned(skyMaterial);
            ReleaseRefugeAssets();
            if(roomWingMaterial) ReleaseOwned(roomWingMaterial);
            if(roomLight) ReleaseOwned(roomLight);
            if(waterMaterial) ReleaseOwned(waterMaterial);
        }
    }
}
