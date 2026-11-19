float4 actorCurve(float4 previous,float4 start,float4 end,float4 next,float alpha)
{
    float4 tangentStart=(end-previous)*.5;
    float4 tangentEnd=(next-start)*.5;
    float t2=alpha*alpha;
    float t3=t2*alpha;
    float4 value=(2*t3-3*t2+1)*start+(t3-2*t2+alpha)*tangentStart
                +(-2*t3+3*t2)*end+(t3-t2)*tangentEnd;
    return clamp(value,min(start,end),max(start,end));
}

// Keep the wrap at contact continuous while limiting interpolation to the
// authored extrema. A lifted foot never dips because adjacent keys overshoot.
#define EVAC_KEY(tab) actorCurve(tab[prev],tab[key],tab[key+1],tab[next],alpha)
float4 actorKeys(int key,float alpha,float side,float upper,float run,float limp)
{
    int prev=key==0?11:key-1;
    int next=key>=10?key-10:key+2;
    float4 walk,fast,hurt;
    if(upper>.5){
        walk=EVAC_KEY(WalkBody); fast=EVAC_KEY(RunBody); hurt=EVAC_KEY(LimpBody);
    }else if(side<0){
        walk=EVAC_KEY(WalkLeft); fast=EVAC_KEY(RunLeft); hurt=EVAC_KEY(LimpLeft);
    }else{
        walk=EVAC_KEY(WalkRight); fast=EVAC_KEY(RunRight); hurt=EVAC_KEY(LimpRight);
    }
    return lerp(lerp(walk,fast,run),hurt,limp);
}
#undef EVAC_KEY

float3 actorPitch(float3 p,float h,float z,float angle)
{
    float s,c; sincos(angle,s,c);
    p.yz-=float2(h,z);
    p.yz=float2(c*p.y-s*p.z,s*p.y+c*p.z)+float2(h,z);
    return p;
}

float3 actorRoll(float3 p,float x,float y,float angle)
{
    float s,c; sincos(angle,s,c);
    p.xy-=float2(x,y);
    p.xy=float2(c*p.x-s*p.y,s*p.x+c*p.y)+float2(x,y);
    return p;
}

float3 actorYaw(float3 p,float x,float angle)
{
    float s,c; sincos(angle,s,c);
    p.x-=x;
    p.xz=float2(c*p.x+s*p.z,-s*p.x+c*p.z);
    p.x+=x;
    return p;
}

float3 actorAlign(float3 p,float3 from,float3 to)
{
    float3 axis=cross(from,to);
    return p+cross(axis,p)+cross(axis,cross(axis,p))/max(.055,1+dot(from,to));
}

float3 actorReach(float3 p,float3 target,float side,float civilian,float elbowBlend)
{
    float3 shoulder=float3(side*.181,1.411,0);
    float3 elbow=float3(side*lerp(.239,.230,civilian),1.150,.004);
    float3 wrist=float3(side*lerp(.180,.211,civilian),.937,.082);
    float3 upperBind=elbow-shoulder;
    float3 lowerBind=wrist-elbow;
    float upperLength=length(upperBind),lowerLength=length(lowerBind);
    float3 delta=target-shoulder;
    float span=length(delta);
    float3 reachAxis=delta/max(.0001,span);
    float3 pole=float3(side*.46,-1,.19);
    float3 bend=normalize(pole-reachAxis*dot(pole,reachAxis)+float3(0,0,.001));
    span=clamp(span,abs(upperLength-lowerLength)+.03,upperLength+lowerLength-.002);
    float along=(upperLength*upperLength-lowerLength*lowerLength+span*span)/(2*span);
    float high=sqrt(max(0,upperLength*upperLength-along*along));
    float3 joint=shoulder+reachAxis*along+bend*high;
    float3 endpoint=shoulder+reachAxis*span;
    float3 upper=shoulder+actorAlign(p-shoulder,upperBind/upperLength,(joint-shoulder)/upperLength);
    float3 lower=joint+actorAlign(p-elbow,lowerBind/lowerLength,(endpoint-joint)/lowerLength);
    return lerp(upper,lower,elbowBlend);
}

float3 actorPatient(float3 p,float joint,float time)
{
    float side=fmod(joint,2)>.5?-1:1;
    bool shoe=joint==11 || joint==12;
    if((joint>=1 && joint<=4) || shoe){
        float hip=side<0?-.23:-.16;
        float knee=side<0?.47:.34;
        if(shoe)p=actorPitch(p,.125,0,-hip-knee+.10);
        p=actorPitch(p,.49,0,knee*(shoe?1:1-smoothstep(.42,.60,p.y)));
        p=actorPitch(p,.87,0,hip);
        p=actorRoll(p,side*.109,.87,side*.032);
    }else if(joint>=5 && joint<=8){
        float distal=1-smoothstep(1.105,1.226,p.y);
        float root=1-smoothstep(1.383,1.455,p.y);
        float3 folded=actorPitch(p,1.15,.014,(side>0?-.24:-.061)*distal);
        folded=actorPitch(folded,1.41,0,side>0?-.065:-.027);
        folded=actorRoll(folded,side*.18,1.41,-side*(side>0?.50:.09));
        p=lerp(p,folded,root);
    }else if(joint==13){
        float neck=smoothstep(1.49,1.65,p.y);
        p=actorYaw(p,0,neck*.12);
        p.z-=neck*.031;
    }
    p.z+=sin(time*2.19)*.0035*smoothstep(.92,1.21,p.y)*(1-smoothstep(1.40,1.51,p.y));
    return p;
}

float3 actorMotion(float3 p,float joint,float4 a,float4 f,float4 left,float4 right,float4 aid)
{
    if(f.y==5)return actorPatient(p,joint,a.z);
    // Market poses share the companion slot but never enter the support solve.
    bool market=aid.w>1.5;
    float3 cast=market?aid.xyz:0;
    if(market)aid=0;
    float hold=f.x==1?smoothstep(0,1,cast.x):0;
    float signal=f.x==1?cast.y:0;
    float thread=f.x==3?cast.y:0;
    float wait=f.x==3?cast.x:0;
    float coil=f.x==2?cast.x:0;
    float sprint=f.x==2?cast.y:0;
    float recover=f.x==2?smoothstep(0,.70,cast.z):0;
    float rebound=f.x==2?smoothstep(.81,1,cast.z):0;
    float cycle=frac(a.x*.159154943)*12;
    int key=min((int)cycle,11);
    float alpha=frac(cycle);
    bool equipment=joint==9;
    float3 rest=p;
    float side=equipment?1:fmod(joint,2)>.5?-1:1;
    float fall=saturate(f.w);
    float live=1-smoothstep(.05,.68,fall);
    hold*=live; signal*=live; thread*=live; wait*=live;
    coil*=live; sprint*=live; recover*=live; rebound*=live;
    float moving=smoothstep(.01,.38,a.y)*live;
    float run=smoothstep(.58,.96,a.y);
    float limp=frac(f.z)*4;
    float4 body=actorKeys(key,alpha,side,1,run,limp)*moving;
    body.x-=coil*.031+recover*.046;
    bool usesLimb=(joint>=1 && joint<=8) || equipment || joint==11 || joint==12;
    float4 limb=0;
    if(usesLimb)limb=actorKeys(key,alpha,side,0,run,limp)*moving;
    float wind=f.x==2?a.z*live:0;
    float tuck=smoothstep(.09,.62,fall);
    float settle=smoothstep(.65,1,fall);
    float hit=saturate(a.w)*live;
    float breath=sin(a.x)*(.005+.007*run)*live;
    float usingRifle=f.y==0 || f.y==4?1:0;
    float aim=usingRifle*(f.y==4?saturate(.35+.65*a.z):a.z*.67);
    float escort=f.y==1?1:0;
    float working=f.y==2?1:0;
    float cargo=f.y==3?1:0;
    bool shoe=joint==11 || joint==12;
    bool leg=(joint>=1 && joint<=4) || shoe;
    bool arm=(joint>=5 && joint<=8) || equipment;
    float lean=f.x==2?.20:f.x==1?.044:.054;
    lean+=working*.22+escort*.11+cargo*.075+limp*.056;
    float torso=lean+wind*.21-hit*.25+run*moving*.13+tuck*.16+breath;
    torso+=coil*-.41+sprint*.40+recover*.27-rebound*.58+abs(thread)*.08+wait*.075;
    float drift=(f.x==2?.025:-.015)*(1-moving)*live;
    float assistRoll=f.x==3?.14*escort:0;
    assistRoll=lerp(assistRoll,-sign(aid.w)*(f.x==3?.17:.076),abs(aid.w)*live);
    assistRoll+=thread*.12+recover*.23-rebound*.31;
    float lookBack=hold*cast.z;
    float turn=lookBack*.54+thread*.86-coil*.23+recover*.26;
    if(leg){
        float knee=limb.y+tuck*(side<0?.40:1.06)-settle*(side<0?.18:.29);
        float hip=limb.x-tuck*(side<0?.22:.69)+settle*(side<0?.11:.23);
        float crouch=saturate(coil+recover);
        knee=lerp(knee,side<0?.68:.49,crouch);
        hip=lerp(hip,side<0?-.42:-.13,crouch);
        float kneeblend=shoe?1:1-smoothstep(.420,.606,p.y);
        float flags=floor(f.z);
        bool fixedFoot=side<0?fmod(flags,2)>.5:flags>1.5;
        float4 support=side<0?left:right;
        if(fixedFoot && shoe){
            // Keep the toe/heel roll from the clip while the ankle follows the
            // planted chain. The support leg can lean sideways without tipping the sole.
            float3 anchor=float3(side*.109,.125,0);
            float3 held=actorPitch(anchor,.49,0,support.y);
            held=actorPitch(held,.87,0,support.x);
            held=actorRoll(held,side*.109,.87,support.w);
            p=actorPitch(p,.125,0,support.z)+held-anchor;
        }else{
            if(shoe)p=actorPitch(p,.125,0,lerp(limb.z+settle*.13*side,-.08-hip-knee,crouch));
            p=actorPitch(p,.49,0,(fixedFoot?support.y:knee)*kneeblend);
            p=actorPitch(p,.87,0,fixedFoot?support.x:hip);
            p=actorRoll(p,fixedFoot?side*.109:side*.101,.87,
                        fixedFoot?support.w:side*tuck*(side<0?.12:.26));
        }
    }else if(arm){
        float elbowBlend=equipment?1:1-smoothstep(1.104,1.226,p.y);
        float shoulderBlend=equipment?1:1-smoothstep(1.39,1.462,p.y);
        float upper=limb.w, elbow=-.11-.55*run*moving;
        float idle=live*(1-moving);
        float yaw=idle*(side<0?.032:-.013);
        float roll=side*(.039+idle*(side<0?.035:.006));
        if(f.x==1){
            float recoil=aim*pow(saturate(a.z),2);
            upper=lerp(upper,(side<0?-.48:-.25)+limb.w*.16,.86);
            elbow=side<0?-.96:-1.17;
            yaw=side<0?.72:-.22;
            upper-=aim*.24+recoil*.085;
            elbow-=aim*.09;
            if(escort>.5){
                // The casualty walks to the soldier's right and just ahead.
                upper=side>0?-.93:-.17+limb.w*.44;
                elbow=side>0?-.39:-.53;
                yaw=side>0?.28:0;
                roll=side>0?.22:-.10;
            }
            if(working>.5){
                upper=-.52+sin(a.x)*.15*side;
                elbow=-.76-sin(a.x)*.17*side;
                yaw=-.22*side;
            }
            if(cargo>.5){
                upper=-.50+limb.w*.11;
                elbow=-.92;
                yaw=-.21*side;
            }
        }else if(f.x==2){
            float reach=saturate(wind*(side<0?1.22:1));
            upper=upper*.71+(side<0?-.44:-.26)-reach*.63-hit*.25;
            elbow=(side<0?-.29:-.45)-reach*.35;
            yaw=-side*(.13+reach*.14);
            roll=side*(.09+hit*.17);
            upper+=coil*(side<0?.87:.61)-sprint*(side<0?.65:1.05)+recover*.51-rebound*1.19;
            elbow-=coil*.43+sprint*.35+rebound*.50;
            roll+=side*(coil*.24+recover*.30+rebound*.41);
        }else{
            upper=upper*.74-(side<0?.30:.07);
            elbow=side<0?-.51:-.25;
            if(escort>.5){
                upper=side<0?.70+limb.w*.12:-.27+limb.w*.41;
                elbow=side<0?-.31:-.61;
                yaw=side<0?.49:-.18;
                roll=side<0?-.39:.09;
            }
            upper-=wait*.17+abs(thread)*(side*thread>0?.43:.07);
            elbow-=wait*.23+abs(thread)*.30;
            roll-=side*abs(thread)*.22;
        }
        if(f.x==1 && side<0 && !equipment)
        {
            // Left palm rises beside the face, then sweeps toward the path.
            upper=lerp(upper,-1.23,signal);
            elbow=lerp(elbow,-.45,signal);
            yaw=lerp(yaw,-.51,signal);
            roll=lerp(roll,-.38,signal);
        }
        upper=lerp(upper,side<0?-.63:.38,tuck)+settle*(side<0?.19:-.13);
        elbow=lerp(elbow,side<0?-.91:-.38,tuck)+settle*.14;
        yaw*=live;
        upper+=idle*(side<0?.018:-.045);
        float3 posed=actorPitch(p,1.15,.014,elbow*elbowBlend);
        posed=actorPitch(posed,1.41,0,upper);
        posed=actorYaw(posed,side*.18,yaw);
        posed=actorRoll(posed,side*.18,1.41,roll+side*tuck*(side<0?.49:.31));
        if(hold>0 && side<0 && !equipment)
            posed=lerp(posed,actorReach(p,float3(-.398,1.677,-.196),side,0,elbowBlend),hold);
        if(!equipment && side*aid.w>.01 && escort>.5){
            float3 target=aid.xyz-float3(body.y,body.x+breath,0);
            target=actorRoll(target,0,.87,-(drift+assistRoll));
            target=actorYaw(target,0,-(body.z+hit*.16));
            target=actorPitch(target,.87,0,-torso);
            posed=lerp(posed,actorReach(p,target,side,f.x==3?1:0,elbowBlend),abs(aid.w)*live);
        }
        p=lerp(p,posed,shoulderBlend);
    }
    if(equipment && usingRifle<.5){
        p=actorPitch(rest,.925,.079,.11);
        p+=float3(.045,.39,-.323);
        p=actorRoll(p,.225,1.315,-.56);
    }
    if(joint==10){
        if(cargo<.5)p=float3(0,1.1,0);
        else p.y+=breath+body.w*.04;
    }
    if(!leg){
        float spine=smoothstep(.85,1.32,p.y);
        float upper=arm || joint==10?1:smoothstep(.83,1.06,p.y);
        float head=joint==13?smoothstep(1.49,1.57,p.y):0;
        if(joint==13)
        {
            float jaw=smoothstep(1.57,1.63,p.y)*(1-smoothstep(1.635,1.665,p.y));
            float muzzle=smoothstep(.046,.088,p.z);
            p.y-=jaw*muzzle*(wind*.017+hit*.008);
            p=actorPitch(p,1.49,0,(body.w*.65-wind*.19+tuck*.24+breath)*head);
            p=actorRoll(p,0,1.49,((f.x==2?.045:0)+hit*.10+settle*.15)*head);
            p=actorYaw(p,0,(lookBack*1.37-thread*.54+wait*cast.z*.22-coil*.24+rebound*.41)*head);
        }
        if(joint==14){
            // A single waist tie lets the lower apron follow the advancing leg.
            float drape=1-smoothstep(.70,1.027,p.y);
            float swing=actorKeys(key,alpha,p.x<0?-1:1,0,run,limp).x*moving;
            p=actorPitch(p,.998,0,min(0,swing)*drape*.66);
            p.z+=drape*.030*moving;
        }
        p=actorPitch(p,.87,0,torso*upper);
        p=actorYaw(p,0,(body.z+turn)*spine+hit*.16*upper);
        p=actorRoll(p,0,.87,(drift+assistRoll)*upper);
        p.x+=f.x==2?.030*spine:0;
        p.y+=breath*spine;
    }
    p.y+=body.x;
    // Pelvis shift tapers to zero at the sole on the stance leg.
    p.x+=body.y*(leg?smoothstep(.12,.86,p.y):1);
    return p;
}

float3 actorViewModel(float3 p,float joint,float4 a,float4 f)
{
    bool support=joint==11;
    bool holding=joint==12 || support;
    if(f.y==0 && a.x>0)
    {
        float t=1-saturate(a.x);
        float reach=smoothstep(.06,.27,t)*(1-smoothstep(.70,.96,t));
        float lower=smoothstep(.20,.43,t)*(1-smoothstep(.58,.79,t));
        float seat=smoothstep(.56,.69,t)*(1-smoothstep(.74,.90,t));
        if(support)
        {
            float wrist=smoothstep(.02,.47,p.z);
            p=actorYaw(p,-.32,reach*.13);
            p=actorPitch(p,-.393,-.008,reach*.10);
            p+=wrist*float3(.022*reach,-.068*lower+.019*seat,-.147*reach);
        }
        if(joint==14)
        {
            p=actorRoll(p,.122,-.147,-lower*.19);
            p+=float3(-.027*lower,-.118*lower,-.028*lower);
        }
    }
    if(f.y==1 && holding)
    {
        float settle=(sin(a.z*5.4)+.32*sin(a.z*10.8))*a.w;
        p.y+=settle*(support?.010:.014)*smoothstep(.02,.41,p.z);
        p.z+=settle*.009*smoothstep(.06,.43,p.z);
    }
    if(f.y==3 && (holding || joint==10))
        p.y+=(sin(a.z*7.2)*.009)*a.w*(holding?smoothstep(.05,.36,p.z):1);
    return p;
}
