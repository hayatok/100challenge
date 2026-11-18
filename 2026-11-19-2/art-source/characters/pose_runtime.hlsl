
// Each instance samples identical pose channels for geometry and shading normals.
#define EVAC_KEY(tab) lerp(tab[key],tab[key+1],alpha)
float4 actorKeys(int key,float alpha,float side,float upper,float run,float limp)
{
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

float3 actorMotion(float3 p,float joint,float4 a,float4 f)
{
    float cycle=frac(a.x*.159154943)*12;
    int key=min((int)cycle,11);
    float alpha=frac(cycle);
    float side=fmod(joint,2)>.5?-1:1;
    float fall=saturate(f.w);
    float live=1-smoothstep(.05,.68,fall);
    float moving=smoothstep(.01,.38,a.y)*live;
    float run=smoothstep(.58,.96,a.y);
    float limp=f.x==3?.68:0;
    float4 body=actorKeys(key,alpha,side,1,run,limp)*moving;
    float4 limb=actorKeys(key,alpha,side,0,run,limp)*moving;
    float wind=f.x==2?a.z*live:0;
    float tuck=smoothstep(0,.62,fall);
    float hit=saturate(a.w)*live;
    bool shoe=joint==11 || joint==12;
    bool leg=(joint>=1 && joint<=4) || shoe;
    bool arm=joint>=5 && joint<=8;
    if(leg){
        float knee=limb.y+tuck*(side<0?.38:1.03);
        float hip=limb.x-tuck*(side<0?.19:.67);
        if(shoe)p=actorPitch(p,.125,0,limb.z);
        if(joint>=3)p=actorPitch(p,.49,0,knee);
        p=actorPitch(p,.87,0,hip);
        if(fall>0)p=actorRoll(p,side*.101,.87,side*tuck*(side<0?.12:.26));
    }else if(arm){
        float upper=limb.w, elbow=-.10-.43*run*moving;
        if(f.x==1){
            // Rifle support arm and trigger arm take different elbow angles.
            upper=lerp(upper,side<0?-.56:-.28,.70);
            elbow=side<0?-.93:-1.24;
            if(f.y==4){upper-=.18;elbow-=.15;}
            if(f.y==1){upper=side<0?-1.05:-.29;elbow=side<0?-.41:-.72;}
            if(f.y==2){upper=-.61+limb.w*.45;elbow=-.96;}
            if(f.y==3){upper=-.56;elbow=-1.02;}
        }else if(f.x==2){
            upper=upper*.72+(side<0?-.50:-.32)-wind*.55;
            elbow=(side<0?-.34:-.52)-wind*.28;
        }else if(side<0){
            upper=upper*.61-.31;
            elbow=-.57;
        }
        upper=lerp(upper,side<0?-.58:.36,tuck);
        elbow=lerp(elbow,side<0?-.86:-.32,tuck);
        if(joint>=7)p=actorPitch(p,1.15,.014,elbow);
        p=actorPitch(p,1.41,0,upper);
        if(fall>0)p=actorRoll(p,side*.18,1.41,side*tuck*(side<0?.47:.23));
    }
    if(joint==9){
        if(f.y>0 && f.y<4)p=float3(.12,1.1,0);
        else {p.y+=.085+(f.y==4?.075:0);p.z+=.065;}
    }
    if(joint==10 && f.y!=3)p=float3(0,1.1,0);
    if(!leg){
        float spine=smoothstep(.85,1.32,p.y);
        float upper=arm || joint==9 || joint==10?1:smoothstep(.83,1.06,p.y);
        float head=smoothstep(1.46,1.55,p.y);
        float lean=f.x==2?.20:f.x==1?.038:.052;
        lean+=f.y==2?.23:f.y==1?.12:0;
        p=actorPitch(p,1.47,0,(body.w*.68-wind*.12+tuck*.19)*head);
        p=actorPitch(p,.87,0,(lean+wind*.21-hit*.26+run*moving*.12+tuck*.16)*upper);
        float sn,cs; sincos(body.z*spine + hit*.16*upper,sn,cs);
        p.xz=float2(cs*p.x+sn*p.z,-sn*p.x+cs*p.z);
        p.x+=f.x==2?.043*spine:0;
    }
    p.y+=body.x;
    // The pelvis transfers weight above a planted foot while its sole stays fixed.
    p.x+=body.y*(leg?smoothstep(.12,.86,p.y):1);
    return p;
}
