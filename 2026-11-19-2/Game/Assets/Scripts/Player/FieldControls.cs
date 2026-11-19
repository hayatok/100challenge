using UnityEngine;

namespace Evac
{
    public sealed partial class GameSession
    {
        Vector2 touchWalk, touchLook, touchOrigin, pointerStart, previousPointer;
        int moveFinger=-1,lookFinger=-1,fireFinger=-1,mapFinger=-1;
        int tapUnit=-1, pinSquad;
        float lastTap, pinAt=-20, stride, stepAt, travelSpeed, dodgeRoll,mapYaw;
        bool mouseMap, mapDragged, focusAim, touchAim;
        float aimBlend, runBlend, stepWeight, turnBank, kickVelocity, cameraKick;
        Vector2 footDrive;
        public bool Aiming => focusAim;
        public void ToggleTouchAim() => touchAim=!touchAim;
        void ReleaseAim()
        {
            touchAim=focusAim=false;
            aimBlend=runBlend=travelSpeed=stepWeight=dodgeRoll=turnBank=cameraKick=kickVelocity=0;
            footDrive=Vector2.zero;
            stride=0;
            stepAt=1.5f;
        }
        Vector3 pinPoint;
        GUIStyle worldText;
        static Vector2 FireCenter => Screen.safeArea.min + Vector2.Scale(ControlPreferences.FirePosition,Screen.safeArea.size);
        static float ThumbRadius => Mathf.Clamp(Screen.height*.097f,29,100);
#if UNITY_WEBGL && !UNITY_EDITOR
        [System.Runtime.InteropServices.DllImport("__Internal")] static extern int BrowserHasLook();
        bool HasMouseLook => BrowserHasLook()!=0;
#else
        bool HasMouseLook => Cursor.lockState==CursorLockMode.Locked;
#endif
        void ClearTouches()
        {
            moveFinger=lookFinger=fireFinger=mapFinger=-1;
            touchWalk=touchLook=Vector2.zero; mouseMap=mapDragged=false;
        }
        void ShowOrderPin(Vector3 p){pinPoint=p;pinAt=Time.time;pinSquad=SelectedSquad;}
        void HandleInput(float dt)
        {
            if(Input.GetKeyDown(KeyCode.F3))UseLamp();
            if(ControlPreferences.Pressed(ControlAction.SwitchView))
            {
                if(sim.Controlled==null) Possess(SelectedSoldier); else CommandMode();
                return;
            }
            for (int i=0;i<3;i++) if(Input.GetKeyDown((KeyCode)((int)KeyCode.Alpha1+i)))
            {
                if(sim.Controlled==null) SelectSquad(i); else OrderAtAim(i);
            }
            if(sim.Controlled==null){ CommandInput(dt);return;}
            if(ControlPreferences.Pressed(ControlAction.FieldAction)) TryAction();
            if(ControlPreferences.Pressed(ControlAction.Reload)) Reload();
            Vector2 walk=ControlPreferences.Movement();
            Vector2 look=Vector2.zero;
            var soldier=sim.Controlled;
            bool canAim=PushedColumn<0 && soldier.reload<=0 && soldier.dodgeTime<=0 && soldier.vaultDuration<=0 && !soldier.carryingCargo && soldier.escortId<0;
            focusAim=canAim && (TouchUI?touchAim:HasMouseLook && Input.GetMouseButton(1));
            aimBlend=Mathf.MoveTowards(aimBlend,focusAim?1:0,dt*(focusAim?6.2f:8f));
            if(TouchUI)
            {
                ReadFingers();walk+=touchWalk;look=touchLook;
                touchLook=Vector2.zero;
            }
            else if(HasMouseLook)
                look=new Vector2(Input.GetAxisRaw("Mouse X"),Input.GetAxisRaw("Mouse Y"))*1.9f;
            else if(Input.GetMouseButtonDown(0)) UpdateCursor();
            float aimMultiplier=focusAim?.55f:1;
            float yaw=sim.Controlled.yaw+look.x*LookSensitivity*aimMultiplier;
            pitch=Mathf.Clamp(pitch-look.y*LookSensitivity*aimMultiplier,-71,77);
            var heading=Quaternion.Euler(0,yaw,0);
            var step=Vector2.ClampMagnitude(walk,1);
            if(ControlPreferences.Pressed(ControlAction.Dodge)) Dodge(step);
            bool rushing=!focusAim && step.y>.48f && (Input.GetKey(KeyCode.LeftShift)||(TouchUI&&step.magnitude>.93f));
            runBlend=Mathf.MoveTowards(runBlend,rushing?1:0,dt*(rushing?4.5f:8));
            float pace=focusAim?.42f:Mathf.Lerp(.74f,1,runBlend);
            Vector2 desired=step*pace;
            footDrive=Vector2.MoveTowards(footDrive,desired,dt*(desired.sqrMagnitude<footDrive.sqrMagnitude?13:8));
            turnBank=Mathf.Lerp(turnBank,Mathf.Clamp(-look.x*.24f-footDrive.x*.7f,-1.5f,1.5f),1-Mathf.Exp(-dt*12));
            Vector3 prev=sim.Controlled.pos;
            sim.Move(heading*new Vector3(footDrive.x,0,footDrive.y),yaw,dt);
            travelSpeed=(sim.Controlled.pos-prev).magnitude/Mathf.Max(.001f,dt);
            stride+=travelSpeed*dt*2.55f;
            stepWeight=Mathf.MoveTowards(stepWeight,Mathf.Clamp01(travelSpeed/4.7f),dt*8);
            if(stride>stepAt)
            {
                bool right=(Mathf.FloorToInt(stepAt/Mathf.PI)&1)!=0;
                sound.Footfall(right,travelSpeed,Mathf.Abs(soldier.pos.z)>48,missionIndex/2);
                stepAt+=Mathf.PI;
            }
            if((!TouchUI && HasMouseLook && Input.GetMouseButton(0))||fireFinger>=0) FireOnce();
        }
        public void Dodge(Vector2 direction)
        {
            if(Phase!="Playing"||sim.Controlled==null)return;
            if(direction.sqrMagnitude<.1f)direction=Vector2.left;
            var delta=Quaternion.Euler(0,sim.Controlled.yaw,0)*new Vector3(direction.x,0,direction.y);
            if(direction.y>.35f && sim.TryVault(delta))
            {
                footDrive=Vector2.zero;
                sound.Signal("step2");
                return;
            }
            if(sim.Dodge(delta)){dodgeRoll=direction.x<0?4:-4;sound.Signal("step2");}
        }
        public void DodgeTouch() => Dodge(touchWalk);
        void ReadFingers()
        {
            float radius=ThumbRadius;
            for(int i=0;i<FieldTouches.Count;i++)
            {
                Touch t=FieldTouches.Get(i);int id=t.fingerId;
                if(t.phase==TouchPhase.Began)
                {
                    if(ui.BlocksPointer(t.position))continue;
                    if(PushedColumn<0 && Vector2.Distance(t.position,FireCenter)<radius*.95f && fireFinger<0) fireFinger=id;
                    else if(t.position.x<Screen.width*.42f&&moveFinger<0){moveFinger=id;touchOrigin=t.position;}
                    else if(lookFinger<0){lookFinger=id;}
                }
                if(t.phase==TouchPhase.Canceled||t.phase==TouchPhase.Ended)
                {
                    if(id==moveFinger){moveFinger=-1;touchWalk=Vector2.zero;}
                    if(id==lookFinger)lookFinger=-1;
                    if(id==fireFinger)fireFinger=-1;
                    continue;
                }
                if(id==moveFinger)touchWalk=Vector2.ClampMagnitude((t.position-touchOrigin)/radius,1);
                if(id==lookFinger)touchLook+=t.deltaPosition*(110f/Mathf.Max(320,Screen.height));
            }
        }
        public void OrderAtAim(int squad)
        {
            if(Phase!="Playing" || sim.Controlled==null || squad<0 || squad>2)return;
            bool staffed=false;
            foreach(var soldier in roster) if(soldier.squad==squad&&soldier.active){staffed=true;break;}
            if(!staffed)return;
            FinishTransferForInput();
            var ray=eye.ViewportPointToRay(new Vector3(.5f,.5f,0));
            var subject=sim.SightContact(ray.origin,ray.direction);
            if(subject!=null && sim.RadioOrder(squad,subject))
            {
                sound.Signal("dispatch");
                return;
            }
            float distance=new Plane(Vector3.up,Vector3.zero).Raycast(ray,out float t)?Mathf.Min(t,42):24;
            Vector3 p=ray.GetPoint(distance);p.y=0;
            sim.Order(squad,sim.OrderFor(squad),p);
            sound.Signal("dispatch");
        }
        void CommandInput(float dt)
        {
            if(Input.GetKeyDown(KeyCode.Q))CycleOrder();
            mapYaw+=((Input.GetKey(KeyCode.X)?1:0)-(Input.GetKey(KeyCode.Z)?1:0))*95*dt;
            Vector2 movement=Vector2.ClampMagnitude(ControlPreferences.Movement(),1);
            mapCenter+=Quaternion.Euler(0,mapYaw,0)*new Vector3(movement.x,0,movement.y)*(zoom*.92f*dt);
            zoom=Mathf.Clamp(zoom-Input.mouseScrollDelta.y*1.6f,10,35);
            if(FieldTouches.Count>0)
            {
                if(FieldTouches.Count==2)
                {
                    var a=FieldTouches.Get(0);var b=FieldTouches.Get(1);
                    if(!ui.BlocksPointer(a.position)&&!ui.BlocksPointer(b.position))
                    {
                        float size=(a.position-b.position).magnitude;
                        float before=(a.position-a.deltaPosition-b.position+b.deltaPosition).magnitude;
                        if(before>1&&size>1) zoom=Mathf.Clamp(zoom*before/size,10,35);
                        if(before>35 && size>35)
                            mapYaw+=Vector2.SignedAngle(a.position-a.deltaPosition-b.position+b.deltaPosition,a.position-b.position);
                    }
                    mapFinger=-1;return;
                }
                Touch t=FieldTouches.Get(0);
                if(t.phase==TouchPhase.Began&&!ui.BlocksPointer(t.position)){mapFinger=t.fingerId;BeginMap(t.position);}
                if(t.fingerId==mapFinger)
                {
                    if(t.phase==TouchPhase.Moved)DragMap(t.position);
                    if(t.phase==TouchPhase.Ended){if(!mapDragged)PointAt(t.position,false);mapFinger=-1;}
                    if(t.phase==TouchPhase.Canceled)mapFinger=-1;
                }
            }
            else if(!Application.isMobilePlatform)
            {
                var pos=(Vector2)Input.mousePosition;
                if(Input.GetMouseButtonDown(1)&&!ui.BlocksPointer(pos))PointAt(pos,true);
                if(Input.GetMouseButtonDown(0)&&!ui.BlocksPointer(pos)){mouseMap=true;BeginMap(pos);}
                if(mouseMap && Input.GetMouseButton(0))DragMap(pos);
                if(Input.GetMouseButtonUp(0)&&mouseMap){mouseMap=false;if(!mapDragged&&!ui.BlocksPointer(pos))PointAt(pos,false);}
            }
            mapCenter.x=Mathf.Clamp(mapCenter.x,-22,22);
            mapCenter.z=Mathf.Clamp(mapCenter.z,-ApproachBlocks.StreetEnd,151f);
        }
        void BeginMap(Vector2 p){pointerStart=previousPointer=p;mapDragged=false;}
        void DragMap(Vector2 p)
        {
            if((pointerStart-p).magnitude>Mathf.Max(6,Screen.height*.009f))mapDragged=true;
            if(mapDragged && MapGround(previousPointer,out var a) && MapGround(p,out var b))mapCenter+=a-b;
            previousPointer=p;
        }
        bool MapGround(Vector2 p,out Vector3 ground)
        {
            Ray r=eye.ScreenPointToRay(p);
            if(new Plane(Vector3.up,Vector3.zero).Raycast(r,out float d)){ground=r.GetPoint(d);return true;}
            ground=default;return false;
        }
        void PointAt(Vector2 screen,bool groundOnly)
        {
            if(TryPlotWaypoint(screen))return;
            if(choosingBeacon)
            {
                if(MapGround(screen,out var site))TargetLamp(site);
                return;
            }
            if(!groundOnly)
            {
                int nearest=-1; float best=Mathf.Max(18,Screen.height*(TouchUI?.045f:.027f));
                for(int i=0;i<roster.Count;i++)
                {
                    if(!RosterAlive(i))continue;
                    Vector3 p=eye.WorldToScreenPoint(roster[i].pos+Vector3.up);
                    float d=Vector2.Distance(p,screen);
                    if(p.z>0&&d<best){best=d;nearest=i;}
                }
                if(nearest>=0)
                {
                    if(nearest==tapUnit && Time.unscaledTime-lastTap<.39f) Possess(nearest);
                    else SelectSoldier(nearest);
                    tapUnit=nearest; lastTap=Time.unscaledTime;return;
                }
            }
            if(MapGround(screen,out var ground))
                IssueOrder(new Vector3(Mathf.Clamp(ground.x,-22,22),0,Mathf.Clamp(ground.z,-ApproachBlocks.StreetEnd,151f)));
        }
        void FrameCamera(float dt,bool snap)
        {
            bool direct=sim.Controlled!=null;
            eye.orthographic=!direct;
            if(direct)
            {
                var u=sim.Controlled;
                float bob=ReducedMotion?0:stepWeight*.026f*(1-aimBlend*.82f);
                dodgeRoll=Mathf.MoveTowards(dodgeRoll,0,dt*13);
                var r=Quaternion.Euler(pitch-(ReducedMotion?0:cameraKick),u.yaw,ReducedMotion?0:dodgeRoll+turnBank);
                var p=u.pos+Vector3.up*(1.52f+sim.VaultLift(u)+Mathf.Sin(2*stride)*bob)+r*Vector3.right*(Mathf.Cos(stride)*bob*.55f);
                eye.transform.SetPositionAndRotation(p,r);
                eye.fieldOfView=Mathf.Lerp(72+(ReducedMotion?0:runBlend*3.5f),53,Mathf.SmoothStep(0,1,aimBlend));
            }
            else
            {
                var r=Quaternion.Euler(51,mapYaw,0);
                var dest=mapCenter-r*Vector3.forward*49;
                float a=snap || ReducedMotion || blendingView ? 1:1-Mathf.Exp(-dt*15);
                eye.transform.SetPositionAndRotation(Vector3.Lerp(eye.transform.position,dest,a),r);
                eye.orthographicSize=Mathf.Lerp(eye.orthographicSize,zoom,a);
            }
            BlendView(dt,direct);
        }
        void LateUpdate()
        {
            if(Phase!="Playing" || sim.Controlled!=null || Current==null) return;
            if(ControlPreferences.Pressed(ControlAction.Dodge))mapCenter=Current.pos;
        }
        void OnGUI()
        {
            if(Phase!="Playing" || ui==null || ui.FieldOverlay || Event.current.type!=EventType.Repaint)return;
            bool chapterOnSite=sim.ChapterPhase==1 || sim.ChapterPhase==3;
            if(worldText==null)worldText=new GUIStyle(GUI.skin.label){font=Resources.Load<Font>("UI/NotoSansJP"),alignment=TextAnchor.MiddleCenter};
            DrawFieldContacts();
            DrawSearchMarkers();
            DrawFleetMarkers();
            BeaconTag();
            ChapterMarker();
            WingMarker();
            ColumnMarkers();
            WaypointMarkers();
            if(blendingView)return;
            if(sim.Controlled!=null)
            {
                float cx=Screen.width*.5f,cy=Screen.height*.5f;
                if(!TouchUI&&!HasMouseLook)
                {
                    worldText.fontSize=Mathf.RoundToInt(Mathf.Clamp(Screen.height*.023f,13,23));
                    worldText.normal.textColor=Color.white;
                    Box(cx-134,cy+28,268,31,new Color(.05f,.08f,.07f,.88f));
                    GUI.Label(new Rect(cx-134,cy+28,268,31),"クリックで視点操作",worldText);
                }
                bool handsFree=PushedColumn<0;
                float gap=5+recoil*5, len=4;
                Color c=hitTime>0?new Color(1,.66f,.28f):new Color(.86f,.93f,.84f,.88f);
                if(handsFree && (aimBlend<.88f || hitTime>0))
                {
                    c.a*=hitTime>0?1:1-aimBlend;
                    Box(cx-gap-len,cy,len,1.5f,c);Box(cx+gap,cy,len,1.5f,c);
                    Box(cx,cy-gap-len,1.5f,len,c);Box(cx,cy+gap,1.5f,len,c);
                }
                if(handsFree && aimBlend>.5f)
                {
                    float dot=Mathf.Clamp(Screen.height*.0032f,1.8f,4);
                    Box(cx-dot*.5f,cy-dot*.5f,dot,dot,new Color(1,.30f,.17f,aimBlend));
                }
                if(hurtTime>0){var shade=new Color(.68f,.13f,.075f,hurtTime*.5f);Box(0,0,Screen.width,Screen.height*.022f,shade);Box(0,Screen.height*.978f,Screen.width,Screen.height*.022f,shade);}
                var pawn=sim.Controlled;
                Vector3 next=pawn.escortId>=0?sim.ActiveExit:pawn.carryingCargo?sim.ActiveDepot:
                    sim.OrderFor(pawn.squad)==SquadOrder.Engineer?sim.EngineerDestination:sim.ActiveAssembly;
                string hint=pawn.escortId>=0?"乗車口":pawn.carryingCargo?"搬入先":
                    sim.OrderFor(pawn.squad)==SquadOrder.Engineer?"作業地点":"集合場所";
                Vector3 tag=next+Vector3.up*1.85f;
                float distance=Vector3.Distance(pawn.pos,next);
                if(HeadingForMarketGate)DrawMarketGateBearing();
                else if(handsFree && !chapterOnSite && distance>3)WorldTag(tag,hint+" "+Mathf.RoundToInt(distance)+"m",new Color(1,.84f,.50f),false);
                if(TouchUI)
                {
                    float r=ThumbRadius;
                    var home=moveFinger>=0?touchOrigin:new Vector2(Screen.width*.13f,Screen.height*.23f);
                    Pad(home,r,"移動",moveFinger>=0);
                    if(moveFinger>=0)Pad(home+touchWalk*r*.63f,r*.32f,"",true);
                    if(handsFree)Pad(FireCenter,r*.77f,"射撃",fireFinger>=0);
                }
            }
            else
            {
                var m=sim.Mission;
                Color route=sim.PassageOpen?new Color(.45f,.92f,.77f,.62f):new Color(.99f,.70f,.27f,.7f);
                if(!chapterOnSite)
                {
                    RouteSegment(m.assembly,m.gate,route);RouteSegment(m.gate,m.exit,route);
                WorldTag(m.assembly+Vector3.up*.60f,"集合",new Color(.61f,.92f,.72f),false);
                WorldTag(m.exit+Vector3.up*1.6f,"乗車口",new Color(.98f,.8f,.5f),false);
                if(sim.CargoRequired||sim.RepairRequired)WorldTag(sim.EngineerDestination+Vector3.up*1.1f,"作業",new Color(.61f,.83f,.98f),false);
                }
                if(sim.HasRequestPoint && !chapterOnSite)WorldTag(sim.RequestPoint+Vector3.up*1.5f,"要請",new Color(.97f,.72f,.43f),false);
                if(sim.AlarmActorId>=0 || sim.AlarmActiveRemaining>0)
                    WorldTag(sim.AlarmPoint+Vector3.up*2.1f,sim.AlarmName,new Color(1,.8f,.4f),true);
                if(Current!=null && Current.active)WorldTag(Current.pos+Vector3.up*2,Current.name,new Color(1,.8f,.42f),true);
                float t=Time.time-pinAt;
                if(t<4)WorldTag(pinPoint+Vector3.up*.45f,SquadName(pinSquad)+" ▼",new Color(.52f,1,.73f),false);
            }
        }
        void RouteSegment(Vector3 a,Vector3 b,Color tint)
        {
            Vector3 pa=eye.WorldToScreenPoint(a+Vector3.up*.14f),pb=eye.WorldToScreenPoint(b+Vector3.up*.14f);
            if(pa.z<=0||pb.z<=0)return;
            Vector2 p=new Vector2(pa.x,Screen.height-pa.y),q=new Vector2(pb.x,Screen.height-pb.y);
            Vector2 d=q-p;float length=d.magnitude;
            if(length<1)return;
            var previous=GUI.matrix;
            GUIUtility.RotateAroundPivot(Mathf.Atan2(d.y,d.x)*Mathf.Rad2Deg,p);
            float dash=Screen.height*.015f;
            for(float x=0;x<length;x+=dash*1.7f)Box(p.x+x,p.y,Mathf.Min(dash,length-x),2,tint);
            GUI.matrix=previous;
        }
        static void Box(float x,float y,float w,float h,Color c)
        {var old=GUI.color;GUI.color=c;GUI.DrawTexture(new Rect(x,y,w,h),Texture2D.whiteTexture);GUI.color=old;}
        void Pad(Vector2 p,float r,string label,bool press)
        {
            var rect=new Rect(p.x-r,Screen.height-p.y-r,r*2,r*2);
            GUI.DrawTexture(rect,Texture2D.whiteTexture,ScaleMode.StretchToFill,true,0,new Color(.07f,.1f,.09f,press?.68f:.42f),0,r);
            GUI.DrawTexture(rect,Texture2D.whiteTexture,ScaleMode.StretchToFill,true,0,new Color(.95f,.88f,.68f,.7f),1.5f,r);
            worldText.fontSize=Mathf.RoundToInt(Mathf.Clamp(r*.39f,12,31));
            worldText.normal.textColor=Color.white;GUI.Label(rect,label,worldText);
        }
        void WorldTag(Vector3 position,string label,Color c,bool tick)
        {
            Vector3 p=eye.WorldToScreenPoint(position);if(p.z<=0)return;
            float h=Mathf.Clamp(Screen.height*.032f,17,32), w=Mathf.Max(58,h*(label.Length+1));
            var rect=new Rect(p.x-w*.5f,Screen.height-p.y-h,w,h);
            if(ui.BlocksPointer(new Vector2(p.x,p.y+h*.5f)))return;
            Box(rect.x,rect.y,w,h,new Color(.055f,.09f,.08f,.87f));
            Box(rect.x,rect.y,3,h,c);
            worldText.fontSize=Mathf.RoundToInt(h*.59f);worldText.normal.textColor=c;GUI.Label(rect,label,worldText);
            if(tick)Box(p.x-1,rect.yMax,2,5,c);
        }
    }
}
