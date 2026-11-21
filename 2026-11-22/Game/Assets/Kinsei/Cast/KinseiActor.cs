using System.Collections.Generic;
using UnityEngine;

/// <summary>Original tailored cast. Feet at origin, forward +Z; caller owns root motion.</summary>
public sealed class KinseiActor : MonoBehaviour
{
    Transform body, chest, head, la, ra, le, re, lh, rh, ll, rl, lk, rk;
    Transform jaw, detailJaw;
    readonly List<Material> extraMaterials = new List<Material>();
    readonly List<Transform> joints = new List<Transform>();
    readonly Dictionary<Transform, Vector3> rests = new Dictionary<Transform, Vector3>();
    Material realisticSkin, propMetal;
    Transform sidearm;
    readonly Dictionary<Transform, Quaternion> lastRotations = new Dictionary<Transform, Quaternion>();
    readonly Dictionary<Transform, Vector3> lastPositions = new Dictionary<Transform, Vector3>();
    Material skin, cloth, dark, shirt, tie, hair, eye, iris, lip, metal, collar;
    Vector3 mirrorContact, conversationEyes, ashtray, previousWorldPosition;
    Transform leftShoe, rightShoe;
    bool hasConversationTargets;
    Vector3 attentionEyes;
    bool hasAttentionTarget;
    SkinnedMeshRenderer leftHandRenderer, rightHandRenderer, faceRenderer;
    readonly Transform[] eyes = new Transform[2];
    readonly KinseiMotionStudy motion = new KinseiMotionStudy();
    public Transform LeftWrist => lh;
    Vector3 localEyeCenter = new Vector3(0,.105f,.075f);
    public Vector3 EyePosition => head.TransformPoint(localEyeCenter);
    Transform mirrorReceiver;
    // Socket coordinates measured against the source head's lid aperture, in metres.
    static readonly Vector3 AdultEye = new Vector3(.0286f,.0974f,.085f);
    static readonly Vector3 YoungEye = new Vector3(.0300f,.1107f,.088f);
    static readonly Vector3 ElderEye = new Vector3(.0286f,.0808f,.0795f);
    float blinkOffset;
    float leftGrip, rightGrip;
    float turnSpeed;
    Quaternion previousWorldRotation;
    bool hasMirrorContact, hasWorldPosition;
    string roleName;
    float phase, stateTime, poseClock;
    bool glanceAfterYield;
    string previous;
    bool ready;

    public void Init(string role, int variant)
    {
        if (ready) return;
        ready = true; roleName = role;
        blinkOffset=.31f + Mathf.Repeat(variant*1.21f+role.Length*.67f,3.72f);
        bool boss = role == "boss", makabe = role == "makabe", kaji = role == "kaji";
        Color suit = boss ? new Color(.78f,.75f,.66f) : makabe ? new Color(.11f,.14f,.17f) : kaji ? new Color(.37f,.32f,.22f) : role == "tatsu" ? new Color(.48f,.105f,.07f) : role=="brother" ? new Color(.23f,.29f,.215f) : new Color(.13f + (variant%3)*.025f,.14f,.16f);
        skin = Mat("Warm skin",new Color(.66f,.44f,.31f),.24f);
        cloth = Mat("Worsted wool",suit,.14f);
        cloth.mainTexture = Resources.Load<Texture2D>("KinseiCast/Wool");
        dark = Mat("Seams and soles",Color.Lerp(suit,new Color(.045f,.033f,.028f),.69f),.18f);
        collar = Mat("Jacket collar and lapels",Color.Lerp(suit,Color.white,.055f),.22f);
        collar.mainTexture = cloth.mainTexture;
        Texture2D woolNormal=Resources.Load<Texture2D>("KinseiCast/WoolNormal");
        foreach(Material wool in new[]{cloth,collar})
        {
            wool.SetTexture("_BumpMap",woolNormal);
            wool.SetFloat("_BumpScale",.81f);
            if(woolNormal)wool.EnableKeyword("_NORMALMAP");
        }
        shirt = Mat("Ivory shirt",new Color(.78f,.75f,.64f),.2f);
        tie = Mat("Burgundy silk",new Color(.24f,.045f,.045f),.38f);
        hair = Mat("Swept hair",kaji || boss ? new Color(.145f,.141f,.140f) : new Color(.100f,.089f,.084f),.17f);
        eye = Mat("Eyes",new Color(.67f,.64f,.56f),.45f); iris = Mat("Dark eyes",new Color(.025f,.018f,.013f),.3f);
        lip = Mat("Mouth and ear shadows",new Color(.29f,.13f,.105f),.18f);
        metal = Mat("Brass",new Color(.57f,.39f,.13f),.7f);
        body = Joint("Pelvis",transform,new Vector3(0,.96f,0));
        Ring("Trousers waist",body,cloth,new[]{new Vector4(0,-.10f,0,.12f),new Vector4(.155f,-.08f,.095f,0),new Vector4(.16f,.055f,.105f,0)},16);
        chest = Joint("Spine",body,new Vector3(0,.06f,0));
        bool doubleBreasted = role == "tatsu";
        // The top of the shoulder rolls toward the neck instead of terminating on a flat ring.
        Shape("Worsted jacket",chest,cloth,new[]{
            R(-.145f,.181f,.119f),R(-.124f,.18f,.122f),R(-.04f,.159f,.116f),
            R(.045f,.155f,.113f),R(.145f,.176f,.12f),R(.242f,.20f,.126f),
            R(.308f,.212f,.12f),R(.347f,.209f,.110f),R(.365f,.193f,.098f),
            R(.382f,.167f,.090f),R(.397f,.108f,.077f),R(.413f,.066f,.067f)},32);
        HalfCollar("Turned jacket collar",chest,collar,.070f,.079f,.397f,.473f);
        HalfCollar("Folded shirt collar",chest,shirt,.060f,.063f,.432f,.468f);
        Patch("Shirt front",chest,shirt,new[]{V(-.073f,.383f,.104f),V(.073f,.383f,.104f),V(.031f,.184f,.125f),V(-.034f,.184f,.125f)});
        for(int side=-1;side<=1;side+=2)
        {
            float s=side;
            Patch("Rolled lapel",chest,collar,new[]{
                V(s*.068f,.413f,.078f),V(s*.132f,.365f,.106f),V(s*.153f,.321f,.111f),
                V(s*.132f,.324f,.127f),V(s*(doubleBreasted?.169f:.147f),.285f,.122f),
                V(s*(doubleBreasted?.055f:.026f),doubleBreasted?.156f:.140f,.132f),
                V(s*.051f,.307f,.135f)});
            Patch("Shirt collar point",chest,shirt,new[]{
                V(s*.062f,.404f,.091f),V(s*.011f,.358f,.135f),
                V(s*.049f,.320f,.133f),V(s*.074f,.366f,.109f)});
            Patch("Hip pocket welt",chest,collar,new[]{
                V(s*.064f,.052f,.108f),V(s*.146f,.064f,.068f),
                V(s*.147f,.036f,.069f),V(s*.065f,.025f,.11f)});
            if(doubleBreasted)
            {
                for(int i=0;i<3;i++)
                    Oval("Double-breasted horn button",chest,dark,V(s*.069f,.166f-i*.072f,.12f),V(.008f,.008f,.004f));
            }
        }
        Patch("Silk tie",chest,tie,new[]{V(-.015f,.349f,.134f),V(.015f,.349f,.134f),
            V(.020f,.167f,.132f),V(0,.151f,.133f),V(-.020f,.167f,.132f)});
        Oval("Tie knot",chest,tie,V(0,.351f,.135f),V(.018f,.019f,.009f));
        if(!doubleBreasted) for(int i=0;i<2;i++)
            Oval("Horn button",chest,dark,V(.023f,.103f-i*.08f,.119f),V(.008f,.008f,.004f));
        Patch("Breast welt",chest,dark,new[]{V(-.154f,.250f,.086f),V(-.091f,.244f,.115f),
            V(-.091f,.238f,.115f),V(-.154f,.244f,.087f)});
        if(doubleBreasted || boss)
            Patch("Pocket square",chest,shirt,new[]{V(-.144f,.25f,.097f),V(-.131f,.270f,.105f),
                V(-.119f,.251f,.112f),V(-.103f,.262f,.118f),V(-.097f,.244f,.119f)});
        Stitch("Center back tailoring seam",chest,dark,.002f,
            V(0,-.14f,-.121f),V(0,-.04f,-.118f),V(0,.045f,-.115f),V(0,.145f,-.122f),
            V(0,.242f,-.128f),V(0,.308f,-.122f),V(0,.347f,-.112f),
            V(0,.365f,-.10f),V(0,.397f,-.079f));
        Stitch("Back vent",chest,dark,.003f,V(-.015f,-.143f,-.122f),
            V(-.008f,-.079f,-.121f),V(0,-.020f,-.118f));
        head=Joint("Head",chest,V(0,.457f,0));
        la=Arm(-1,out le,out lh); ra=Arm(1,out re,out rh);
        ll=Leg(-1,out lk,out leftShoe); rl=Leg(1,out rk,out rightShoe);
        if(boss) body.localScale=V(1.10f,1,1.10f);
        if(role=="brother") transform.localScale*=.988f;
        UpgradeSkin(boss,makabe,kaji,variant);
        BuildSidearm();
        MergeSurfaces(transform);
        KinseiWardrobeBinding.Dress(gameObject, role, variant);
    }
    Transform Arm(int side,out Transform elbow,out Transform hand)
    {
        var a=Joint(side<0?"Left shoulder":"Right shoulder",chest,V(side*.196f,.325f,.004f));
        elbow=Joint("Elbow",a,V(0,-.265f,0));
        hand=Joint("Wrist",elbow,V(0,-.255f,0));
        Transform sleeve = Shape("Rounded sleeve",a,cloth,new[]{
            R(.054f,.024f,.037f),R(.043f,.053f,.065f),R(.019f,.071f,.073f),R(-.017f,.074f,.074f),
            R(-.069f,.067f,.068f),R(-.138f,.060f,.062f),R(-.195f,.054f,.058f),
            R(-.229f,.053f,.053f),R(-.259f,.048f,.05f),R(-.285f,.05f,.049f),
            R(-.320f,.047f,.047f),R(-.369f,.043f,.044f),R(-.450f,.037f,.042f),R(-.500f,.034f,.037f)},24);
        DeformAroundJoint(sleeve,a,elbow,-.263f,.10f);
        Shape("Shirt cuff",elbow,shirt,new[]{R(-.228f,.034f,.036f),R(-.258f,.031f,.034f)},20);
        for(int i=0;i<3;i++)
            Oval("Cuff button",elbow,dark,V(side*.024f,-.222f+i*.012f,-.028f),V(.005f,.004f,.005f));
        return a;
    }
    void BuildFallbackFace(bool boss,bool kaji)
    {
        Shape("Fallback neck",head,skin,new[]{R(-.069f,.057f,.052f),R(.017f,.054f,.048f)},16);
        Shape("Fallback face",head,skin,new[]{R(-.016f,.046f,.048f),R(.005f,.069f,.067f),
            R(.056f,.082f,.075f),R(.105f,.086f,.073f),R(.16f,.079f,.067f),
            R(.20f,.057f,.051f),R(.217f,.009f,.01f)},24);
        // Nose bridge, nostrils, cheeks, inset eyes, lids and eyebrows distinguish a human face.
        Oval("Nose bridge",head,skin,V(0,.092f,.077f),V(.016f,.040f,.025f));
        Oval("Nose tip",head,skin,V(0,.067f,.098f),V(.023f,.014f,.018f));
        for(int side=-1;side<=1;side+=2)
        {
            Oval("Nostril",head,lip,V(side*.011f,.059f,.107f),V(.005f,.003f,.003f));
            Oval("Cheekbone",head,skin,V(side*.053f,.066f,.056f),V(.027f,.024f,.027f));
            Oval("Eye socket",head,lip,V(side*.034f,.105f,.068f),V(.027f,.013f,.014f));
            Oval("Eye white",head,eye,V(side*.034f,.105f,.079f),V(.021f,.007f,.006f));
            Oval("Iris",head,iris,V(side*.032f,.105f,.0845f),V(.006f,.006f,.002f));
            Oval("Upper eyelid",head,skin,V(side*.034f,.113f,.079f),V(.024f,.005f,.007f));
            var brow=Oval("Strong brow",head,hair,V(side*.035f,.124f,.077f),V(.027f,.005f,.006f)); brow.localRotation=Quaternion.Euler(0,0,side*-8);
            Oval("Ear",head,skin,V(side*.085f,.085f,0),V(.019f,.034f,.016f));
            Oval("Ear concha",head,lip,V(side*.096f,.084f,.009f),V(.007f,.020f,.006f));
            Oval("Sideburn",head,hair,V(side*.078f,.119f,-.001f),V(.009f,.036f,.035f));
        }
        jaw=Joint("Mouth expression",head,V(0,.034f,.073f));
        Oval("Lower lip",jaw,skin,V(0,-.006f,.005f),V(.029f,.006f,.006f));
        Oval("Closed mouth",jaw,lip,V(0,0,.010f),V(.030f,.0025f,.003f));
        Oval("Upper lip",jaw,lip,V(0,.003f,.007f),V(.024f,.003f,.005f));
        Shape("Slicked hair",head,hair,new[]{R(.142f,.082f,.070f),R(.185f,.084f,.071f),R(.219f,.060f,.052f),R(.232f,.015f,.014f)},24);
        // Individual swept ridges catch light instead of a spherical hair cap.
        for(int i=0;i<7;i++) { var ridge=Oval("Comb wave",head,hair,V(-.061f+i*.019f,.205f,.022f),V(.012f,.022f,.060f)); ridge.localRotation=Quaternion.Euler(14,0,-14); }
        if(boss) { Oval("Moustache",head,hair,V(0,.044f,.087f),V(.029f,.006f,.006f)); }
        if(kaji) Patch("Old scar",head,lip,new[]{V(-.055f,.127f,.078f),V(-.050f,.126f,.079f),V(-.027f,.074f,.086f),V(-.030f,.074f,.086f)});
    }

    void BuildFallbackHand(Transform hand,int side)
    {
        Oval("Palm",hand,skin,V(0,-.039f,.007f),V(.036f,.049f,.019f));
        for(int f=0;f<4;f++)
        {
            var finger=Joint("Finger "+f,hand,V(-.024f+f*.016f,-.067f,.01f));
            Shape("Finger",finger,skin,new[]{R(0,.008f,.009f),R(-.034f,.007f,.008f),R(-.047f,.004f,.005f)},8);
            finger.localRotation=Quaternion.Euler(-10+f*3,0,3-f*2);
        }
        var thumb=Oval("Thumb",hand,skin,V(-side*.033f,-.030f,.018f),V(.013f,.028f,.012f)); thumb.localRotation=Quaternion.Euler(20,0,side*-27);
    }

    Transform Leg(int side,out Transform knee,out Transform shoe)
    {
        var leg=Joint("Hip",body,V(side*.084f,-.055f,0));
        knee=Joint("Knee",leg,V(0,-.39f,0));
        var trouser = Shape("Continuous pressed trouser",leg,cloth,new[]{
            R(.079f,.093f,.095f),R(.02f,.094f,.094f),R(-.072f,.088f,.085f),R(-.17f,.080f,.080f),
            R(-.28f,.069f,.073f),R(-.345f,.063f,.069f),R(-.386f,.06f,.065f),
            R(-.423f,.062f,.063f),R(-.49f,.056f,.062f),R(-.59f,.052f,.057f),
            R(-.70f,.048f,.053f),R(-.763f,.047f,.055f),R(-.807f,.045f,.050f)},24);
        DeformAroundJoint(trouser,leg,knee,-.388f,.12f);
        Stitch("Pressed front crease",knee,dark,.0012f,V(0,-.072f,.064f),V(0,-.20f,.059f),V(0,-.363f,.055f));
        shoe=Joint("Ankle",knee,V(0,-.445f,.012f));
        Oval("Leather oxford",shoe,dark,V(0,-.017f,.054f),V(.055f,.050f,.122f));
        Oval("Shoe sole",shoe,dark,V(0,-.052f,.056f),V(.056f,.017f,.124f));
        Stitch("Cap toe seam",shoe,dark,.0018f,V(-.045f,.004f,.119f),V(0,.020f,.125f),V(.045f,.004f,.119f));
        return leg;
    }

    static void DeformAroundJoint(Transform surface, Transform proximal, Transform distal, float jointY, float width)
    {
        MeshFilter filter=surface.GetComponent<MeshFilter>();
        Mesh mesh=filter.sharedMesh;
        Material material=surface.GetComponent<MeshRenderer>().sharedMaterial;
        Transform placement=surface.parent;
        var deformed=new GameObject(surface.name).transform;
        deformed.SetParent(placement,false);
        var renderer=deformed.gameObject.AddComponent<SkinnedMeshRenderer>();
        var vertices=mesh.vertices;
        var weights=new BoneWeight[vertices.Length];
        for(int i=0;i<weights.Length;i++)
        {
            float influence=Mathf.SmoothStep(0,1,Mathf.InverseLerp(jointY+width*.5f,jointY-width*.5f,vertices[i].y));
            weights[i]=new BoneWeight {boneIndex0=0,weight0=1-influence,boneIndex1=1,weight1=influence};
        }
        mesh.boneWeights=weights;
        mesh.bindposes=new[]{proximal.worldToLocalMatrix*deformed.localToWorldMatrix,distal.worldToLocalMatrix*deformed.localToWorldMatrix};
        renderer.sharedMesh=mesh;
        renderer.sharedMaterial=material;
        renderer.bones=new[]{proximal,distal};
        renderer.rootBone=proximal;
        renderer.localBounds=new Bounds(new Vector3(0,-.27f,0),new Vector3(1.3f,1.65f,1.3f));
        filter.sharedMesh=null;
        surface.gameObject.SetActive(false);
        Destroy(surface.gameObject);
    }
    public void Pose(string state,float speed,float action=0f)
    {
        if(!ready) Init("guard",0);
        if(previous!=state)
        {
            glanceAfterYield=roleName=="brother" && previous=="surrender" && state=="idle";
            if((state=="walk"||state=="run")&&previous!="walk"&&previous!="run")phase=0;
            previous=state;
            stateTime=0;
        }
        float dt=Time.deltaTime;
        stateTime+=dt;
        poseClock+=dt;
        Vector3 displacement=hasWorldPosition?transform.position-previousWorldPosition:Vector3.zero;
        displacement.y=0;
        float distance=displacement.magnitude;
        float yawDelta=hasWorldPosition?Vector3.SignedAngle(previousWorldRotation*Vector3.forward,transform.forward,Vector3.up):0;
        turnSpeed=Mathf.Lerp(turnSpeed,Mathf.Clamp(yawDelta*1.3f,-13,13),1-Mathf.Exp(-dt*12));
        previousWorldPosition=transform.position;
        previousWorldRotation=transform.rotation;
        hasWorldPosition=true;
        bool run=state=="run";
        bool locomotion=state=="walk" || run;
        float stride=run?1.59f:Mathf.Lerp(.72f,1.32f,Mathf.InverseLerp(.5f,2.55f,speed));
        if(locomotion)
            phase=Mathf.Repeat(phase+(distance<.45f?distance:0)/stride+Mathf.Abs(yawDelta)*.00045f,1);
        float t=poseClock, swing=Mathf.Sin(phase*2*Mathf.PI);
        foreach(var j in joints)
        {
            lastPositions[j]=j.localPosition; lastRotations[j]=j.localRotation;
            j.localPosition=rests[j]; j.localRotation=Quaternion.identity;
        }
        if(sidearm!=null)sidearm.gameObject.SetActive(state=="shoot" || state=="aim");
        body.localPosition+=V(Mathf.Sin(t*.75f)*.006f,Mathf.Sin(t*2.1f)*.003f,0);
        chest.localRotation=Quaternion.Euler(Mathf.Sin(t*1.7f)*.85f,turnSpeed*.4f,Mathf.Sin(t*.6f)*.7f);
        la.localRotation=Quaternion.Euler(-5,0,-4);
        ra.localRotation=Quaternion.Euler(-5,0,4);
        le.localRotation=Quaternion.Euler(-9,0,2);
        re.localRotation=Quaternion.Euler(-10,0,-2);
        lh.localRotation=Quaternion.Euler(-8,68,2);
        rh.localRotation=Quaternion.Euler(-8,-68,-2);
        float gripLeft=.32f, gripRight=.44f;
        head.localRotation=Quaternion.Euler(Mathf.Sin(t*1.1f)*1.5f,Mathf.Sin(t*.45f)*3+turnSpeed*.65f,0);

        if(locomotion && !motion.Pose(run,phase,dt,turnSpeed,body,chest,la,ra,le,re))
        {
            float a=run?36:23;
            body.localPosition+=V(swing*.014f,(run?-.106f:-.073f)+Mathf.Abs(swing)*(run?.045f:.025f),0);
            body.localRotation=Quaternion.Euler(0,-4*swing,2*swing);
            chest.localRotation=Quaternion.Euler(run?11:4,4*swing+turnSpeed*.5f,-2.4f*swing);
            la.localRotation=Quaternion.Euler(-swing*a,turnSpeed*.2f,-5);
            ra.localRotation=Quaternion.Euler(swing*a,turnSpeed*.2f,5);
            le.localRotation=Quaternion.Euler(run?-54:-18,0,0);
            re.localRotation=Quaternion.Euler(run?-61:-22,0,0);
            PlantFoot(ll,lk,leftShoe,-1,phase,stride,run);
            PlantFoot(rl,rk,rightShoe,1,Mathf.Repeat(phase+.5f,1),stride,run);
        }
        if(state=="guard")
        {
            bool leadRight=roleName!="brother";
            int lead=leadRight?1:-1;
            body.localPosition+=V(-lead*.024f,-.047f, -.006f);
            body.localRotation=Quaternion.Euler(0,-lead*13,lead*2);
            chest.localRotation=Quaternion.Euler(7,lead*20+Mathf.Sin(t*1.3f)*1.5f,-lead*5);
            la.localRotation=Quaternion.Euler(leadRight?-27:-52,-12,-13);
            ra.localRotation=Quaternion.Euler(leadRight?-47:-29,13,10);
            le.localRotation=Quaternion.Euler(leadRight?-47:-61,2,-4);
            re.localRotation=Quaternion.Euler(leadRight?-65:-50,-2,4);
            lh.localRotation=Quaternion.Euler(-12,38,0);
            rh.localRotation=Quaternion.Euler(-9,-30,0);
            gripLeft=.62f;gripRight=.67f;
            PlantGuardFoot(ll,lk,leftShoe,-1,lead);
            PlantGuardFoot(rl,rk,rightShoe,1,lead);
            if(hasAttentionTarget)AimHead(attentionEyes,.78f);
        }
        if(state=="sit"||state=="talk"||state=="listen-call")
        {
            bool tatsu=roleName=="tatsu";
            body.localPosition+=V(tatsu?.025f:-.021f,-.412f,tatsu?.023f:-.012f);
            body.localRotation=Quaternion.Euler(0,tatsu?-8:7,tatsu?2:-2);
            ll.localRotation=Quaternion.Euler(-85,0,-7);
            rl.localRotation=Quaternion.Euler(-92,0,8);
            lk.localRotation=Quaternion.Euler(79,0,1);
            rk.localRotation=Quaternion.Euler(94,0,-1);
            leftShoe.localRotation=Quaternion.Euler(6,-5,0);
            rightShoe.localRotation=Quaternion.Euler(-2,6,0);
            chest.localRotation=Quaternion.Euler(tatsu?8:6,tatsu?7:-5,Mathf.Sin(t*1.5f)*.7f);
            la.localRotation=Quaternion.Euler(tatsu?-19:-27,-6,-11);
            ra.localRotation=Quaternion.Euler(tatsu?-31:-20,6,9);
            le.localRotation=Quaternion.Euler(-69,-6,0);
            re.localRotation=Quaternion.Euler(-54,6,0);
            if(state=="talk" && hasConversationTargets)
            {
                float glance=tatsu?Ease(.10f,.55f,stateTime)*(1-Ease(1.3f,1.95f,stateTime)):0;
                AimHead(Vector3.Lerp(conversationEyes,ashtray,glance*.91f),1);
                float speaker=tatsu ? Ease(1.35f,1.55f,stateTime)*(1-Ease(2.56f,2.85f,stateTime))
                    : Ease(.55f,.67f,stateTime)*(1-Ease(1.35f,1.60f,stateTime));
                float syllable=Mathf.Max(0,Mathf.Sin(stateTime*27+.11f))*Mathf.Lerp(.38f,1,Mathf.Sin(stateTime*9)*.5f+.5f);
                if(detailJaw) detailJaw.localRotation=Quaternion.Euler(speaker*syllable*4.7f,0,0);
                else jaw.localPosition+=Vector3.down*(speaker*syllable*.0045f);
                if(!tatsu)
                {
                    float nod=Ease(.66f,.80f,stateTime)*(1-Ease(.84f,1.1f,stateTime));
                    head.localRotation*=Quaternion.Euler(nod*7,0,0);
                }
            }
        }
        if(state=="listen-call")
        {
            float turn=Ease(.05f,.36f,action);
            float nod=Ease(.34f,.48f,action)*(1-Ease(.48f,.69f,action));
            if(hasAttentionTarget)AimHead(attentionEyes,turn);
            chest.localRotation*=Quaternion.Euler(4*turn,-5*turn,0);
            head.localRotation*=Quaternion.Euler(7*nod,-3*(1-turn),1.3f*turn);
            le.localRotation*=Quaternion.Euler(-10*turn,0,0);
            gripLeft=.54f-.23f*turn;gripRight=.48f-.16f*turn;
        }
        if(state=="surrender")
        {
            bool brother=roleName=="brother";
            float duck=brother?Ease(0,.26f,stateTime):0;
            float lower=brother?Ease(.60f,1.42f,stateTime):0;
            body.localPosition+=V(-duck*.027f,-duck*.039f,0);
            chest.localRotation=Quaternion.Euler(8*duck,-21*duck,-8*duck);
            head.localRotation=Quaternion.Euler(16*duck,-21*duck,-7*duck);
            la.localRotation=Quaternion.Euler(-31+14*lower,0,-58+34*lower);
            ra.localRotation=Quaternion.Euler(-31+16*lower,0,60-31*lower);
            le.localRotation=Quaternion.Euler(-97+60*lower,-11,9);
            re.localRotation=Quaternion.Euler(-101+57*lower,19,-8);
            lh.localRotation=Quaternion.Euler(1,26,19);
            rh.localRotation=Quaternion.Euler(1,-19,-14);
            gripLeft=.08f;gripRight=.12f;
        }
        if(state=="brother-call")
        {
            float turn=Ease(.25f,.61f,action);
            float settle=Ease(.60f,.93f,action);
            body.localPosition+=V(-.028f+.038f*turn,-.028f+settle*.014f,-.009f);
            body.localRotation=Quaternion.Euler(0,Mathf.Lerp(-23,-7,turn),-4+settle*3);
            chest.localRotation=Quaternion.Euler(Mathf.Lerp(12,3,turn),Mathf.Lerp(-19,3,turn),-7+settle*4);
            head.localRotation=Quaternion.Euler(Mathf.Lerp(20,-2,turn),Mathf.Lerp(-24,4,turn),-5+settle*4);
            la.localRotation=Quaternion.Euler(-14,-11,-8);
            ra.localRotation=Quaternion.Euler(-20,13,9);
            le.localRotation=Quaternion.Euler(-24,6,0);
            re.localRotation=Quaternion.Euler(-29,-5,0);
            gripLeft=.47f;gripRight=.44f;
            float line=Ease(.58f,.65f,action)*(1-Ease(.86f,.99f,action));
            if(detailJaw)
                detailJaw.localRotation=Quaternion.Euler(Mathf.Max(0,Mathf.Sin(stateTime*24))*line*7,0,0);
        }
        if(glanceAfterYield)
        {
            float look=Ease(.08f,.62f,stateTime);
            chest.localRotation=Quaternion.Euler(Mathf.Lerp(9,3,look),Mathf.Lerp(-31,-4,look),0);
            head.localRotation=Quaternion.Euler(Mathf.Lerp(18,-1,look),Mathf.Lerp(-33,4,look),-2);
        }
        if(state=="flinch")
        {
            float impulse=Ease(0,.038f,stateTime)*(1-Ease(.067f,.235f,stateTime));
            body.localPosition+=V(-.029f*impulse,-.028f*impulse,-.045f*impulse);
            chest.localRotation*=Quaternion.Euler(-14*impulse,-24*impulse,13*impulse);
            head.localRotation*=Quaternion.Euler(-12*impulse,-11*impulse,5*impulse);
            la.localRotation*=Quaternion.Euler(-15*impulse,0,-12*impulse);
            ra.localRotation*=Quaternion.Euler(-30*impulse,-10*impulse,12*impulse);
        }
        if(state=="aim" || state=="shoot")
        {
            bool firing=state=="shoot";
            float raise=firing?1:Ease(0,.17f,stateTime);
            float recoil=firing?Ease(0,.036f,stateTime)*(1-Ease(.045f,.16f,stateTime)):0;
            chest.localRotation=Quaternion.Euler(-1,-10*raise,3*raise);
            head.localRotation=Quaternion.Euler(-4,5*raise,0);
            ra.localRotation=Quaternion.Euler(Mathf.Lerp(-47,-88,raise)-recoil*9,-2,6);
            re.localRotation=Quaternion.Euler(Mathf.Lerp(-41,-11,raise)-recoil*10,0,0);
            rh.localRotation=Quaternion.Euler(9,30,2);
            la.localRotation=Quaternion.Euler(Mathf.Lerp(-27,-61,raise),-27*raise,-11);
            le.localRotation=Quaternion.Euler(-44,0,0);
            gripLeft=.68f;gripRight=.97f;
            if(hasAttentionTarget)AimHead(attentionEyes,.87f);
        }
        if(state=="punch") { float p=Mathf.Sin(Mathf.Clamp01(stateTime/.45f)*Mathf.PI); ra.localRotation=Quaternion.Euler(-90*p,-25*p,10); re.localRotation=Quaternion.Euler(-80*(1-p),0,0); chest.localRotation=Quaternion.Euler(0,-22*p,0); }
        if(state=="fall") { float p=Mathf.SmoothStep(0,1,Mathf.Clamp01(stateTime/.8f)); body.localPosition=V(0,.96f-.79f*p,0); body.localRotation=Quaternion.Euler(-86*p,0,8*p); ll.localRotation=Quaternion.Euler(12*p,0,-12*p); rl.localRotation=Quaternion.Euler(-15*p,0,18*p); la.localRotation=Quaternion.Euler(-32*p,0,-55*p); ra.localRotation=Quaternion.Euler(25*p,0,48*p); }
        if(state=="mirror")
        {
            float work=Ease(.02f,.47f,action);
            body.localPosition+=V(-.021f*work,-.132f*work,.035f*work);
            body.localRotation=Quaternion.Euler(0,-8*work,3*work);
            chest.localRotation=Quaternion.Euler(13*work,-4*work,1*work);
            la.localRotation=Quaternion.Euler(-36*work,-8*work,-12*work);
            ra.localRotation=Quaternion.Euler(-52*work,7*work,12*work);
            le.localRotation=Quaternion.Euler(-30*work,0,0);
            re.localRotation=Quaternion.Euler(-27*work,0,0);
            PlantGuardFoot(ll,lk,leftShoe,-1,-1);
            PlantGuardFoot(rl,rk,rightShoe,1,-1);
            if(mirrorReceiver)
                AimHead(mirrorReceiver.TransformPoint(V(.18f,.26f,-.13f)),.87f);
        }
        float damping=state=="flinch"?31:state=="fall"?20:locomotion?22:12;
        float blend=1-Mathf.Exp(-dt*damping);
        foreach(var j in joints)
        {
            j.localPosition=Vector3.Lerp(lastPositions[j],j.localPosition,blend);
            j.localRotation=Quaternion.Slerp(lastRotations[j],j.localRotation,blend);
        }
        if(locomotion)motion.Feet(transform,stride,turnSpeed,ll,lk,leftShoe,rl,rk,rightShoe,SolveLimb);
        else motion.Reset();
        if(state=="mirror" && mirrorReceiver)
        {
            float contact=Ease(.06f,.32f,action);
            float turn=Ease(.25f,.91f,action);
            Vector3 axis=mirrorReceiver.right;
            Vector3 rim=Quaternion.AngleAxis(Mathf.Lerp(-22,18,turn),axis)*(-mirrorReceiver.forward);
            Vector3 wheel=mirrorReceiver.TransformPoint(V(.4328f,.215f,.002f)) + rim*.076f;
            Vector3 palmNormal=-axis*.9659f-rim*.2588f;
            Vector3 tangent=Vector3.Cross(axis,rim);
            Vector3 fingers=Vector3.ProjectOnPlane(tangent*.32f+rim*.68f,palmNormal).normalized;
            Vector3 bezel=mirrorReceiver.TransformPoint(V(.139f,.09f,-.191f));
            gripRight=Mathf.Lerp(.43f,.56f,contact);
            gripLeft=.18f;
            ReachPalm(ra,re,rh,wheel,palmNormal,fingers,contact,transform.right,V(0,-.07765f,.0215f));
            ReachPalm(la,le,lh,bezel,mirrorReceiver.forward,mirrorReceiver.up,contact,-transform.right);
        }
        else if(state=="mirror" && hasMirrorContact)
        {
            float contact=Ease(.06f,.32f,action);
            gripLeft=.17f;gripRight=.17f;
            ReachPalm(la,le,lh,mirrorContact-transform.right*.12f,transform.forward,Vector3.up,contact,-transform.right);
            ReachPalm(ra,re,rh,mirrorContact+transform.right*.12f,transform.forward,Vector3.up,contact,transform.right);
        }
        if(state=="talk" && roleName=="tatsu" && hasConversationTargets)
        {
            float weight=Ease(.18f,.57f,stateTime)*(1-Ease(1.65f,2.0f,stateTime));
            gripRight=Mathf.Lerp(gripRight,.24f,weight);
            ReachPalm(ra,re,rh,ashtray+Vector3.up*.033f,Vector3.down,transform.forward,weight,transform.right);
        }
        if(state=="brother-call")
        {
            float touch=Ease(.18f,.42f,action)*(1-Ease(.72f,.99f,action));
            Vector3 fingers=chest.TransformDirection(V(-.32f,.95f,0));
            ReachPalm(ra,re,rh,chest.TransformPoint(V(.061f,.355f,.141f)),-chest.forward,
                fingers,touch,chest.right);
            gripRight=Mathf.Lerp(gripRight,.22f,touch);
        }
        if(state=="print-ticket" && hasAttentionTarget) {
            float reach=Ease(0,.50f,stateTime)*(1-Ease(1.69f,2.24f,stateTime));
            AimHead(attentionEyes,.80f*reach);
            ReachPalm(ra,re,rh,attentionEyes,Vector3.down,transform.forward,reach,transform.right);
            gripRight=Mathf.Lerp(.22f,.68f,reach);
        }
        leftGrip=Mathf.Lerp(leftGrip,gripLeft,blend);
        rightGrip=Mathf.Lerp(rightGrip,gripRight,blend);
        if(leftHandRenderer)leftHandRenderer.SetBlendShapeWeight(0,leftGrip*100);
        if(rightHandRenderer)rightHandRenderer.SetBlendShapeWeight(0,rightGrip*100);
        if(faceRenderer)
        {
            float blinkTime=Mathf.Repeat(poseClock+blinkOffset,4.11f+blinkOffset*.48f);
            float blink=Ease(0,.050f,blinkTime)*(1-Ease(.057f,.151f,blinkTime));
            if(state=="brother-call")
                blink=Mathf.Max(blink,Ease(.522f,.544f,action)*(1-Ease(.551f,.597f,action)));
            if(state=="fall")blink=Mathf.Max(blink,Ease(.15f,.65f,stateTime)*.94f);
            float squint=state=="aim" || state=="shoot"?.15f:0;
            float closure=Mathf.Max(blink,squint);
            faceRenderer.SetBlendShapeWeight(0,closure*100);
            if(roleName=="kaji" || roleName=="brother") {
                float lift=state=="listen-call"?Ease(.04f,.22f,action)*(1-Ease(.36f,.75f,action)):
                    state=="brother-call"?.62f*Ease(.26f,.49f,action)*(1-Ease(.71f,.96f,action)):0;
                faceRenderer.SetBlendShapeWeight(1,lift*100);
            }
            foreach(Transform eyeball in eyes)
                eyeball.localScale=V(1,Mathf.Lerp(1,.19f,closure),Mathf.Lerp(1,.82f,closure));
        }
    }

    void PlantGuardFoot(Transform hip,Transform knee,Transform ankle,int side,int lead)
    {
        float z=side==lead?.085f:-.078f;
        SolveLimb(hip,knee,ankle,transform.TransformPoint(V(side*.128f,.069f,z)),transform.forward,1);
        ankle.rotation=transform.rotation*Quaternion.Euler(0,side*10,0);
    }

    static float Ease(float start,float end,float time) => Mathf.SmoothStep(0,1,Mathf.InverseLerp(start,end,time));

    void AimHead(Vector3 worldPoint,float weight)
    {
        Vector3 direction=chest.InverseTransformDirection(worldPoint-EyePosition);
        float yaw=Mathf.Atan2(direction.x,direction.z)*Mathf.Rad2Deg;
        float pitch=-Mathf.Atan2(direction.y,new Vector2(direction.x,direction.z).magnitude)*Mathf.Rad2Deg;
        head.localRotation=Quaternion.Slerp(head.localRotation,
            Quaternion.Euler(Mathf.Clamp(pitch,-20,29),Mathf.Clamp(yaw,-55,55),0),weight);
    }

    void PlantFoot(Transform hip,Transform knee,Transform ankle,int side,float progress,float stride,bool run)
    {
        float stance=run?.49f:.59f;
        bool grounded=progress<stance;
        float p=grounded?progress/stance:(progress-stance)/(1-stance);
        float extent=Mathf.Min(stride*stance*.42f,run?.30f:.27f);
        float ahead=grounded?Mathf.Lerp(extent,-extent,p):Mathf.SmoothStep(-extent,extent,p);
        float lift=grounded?0:Mathf.Sin(p*Mathf.PI)*(run?.133f:.087f);
        float pitch=grounded?Mathf.Lerp(0,19,Ease(.73f,1,p)):Mathf.Lerp(19,-8,Ease(0,.75f,p))+8*Ease(.79f,1,p);
        float height=.074f+lift+(grounded?.032f*Ease(.73f,1,p):.032f*(1-Ease(0,.24f,p)));
        Vector3 target=transform.TransformPoint(V(side*(.091f+Mathf.Abs(turnSpeed)*.0009f),height,ahead+.013f));
        SolveLimb(hip,knee,ankle,target,transform.forward,1);
        ankle.rotation=transform.rotation*Quaternion.Euler(pitch,side*5+turnSpeed*.22f,0);
    }

    /// <summary>The lower receiver hinge. Wheel and bezel contacts follow the moving case.</summary>
    public void SetMirrorWheel(Transform receiverHinge) => mirrorReceiver=receiverHinge;

    /// <summary>World-space frame midpoint for callers without the receiver hierarchy.</summary>
    public void SetMirrorTarget(Vector3 worldContact)
    {
        mirrorContact=worldContact;
        hasMirrorContact=true;
    }

    /// <summary>World-space attention target while standing ready or aiming.</summary>
    public void SetAttentionTarget(Vector3 worldEyes)
    {
        attentionEyes=worldEyes;
        hasAttentionTarget=true;
    }

    /// <summary>Sets the seated partner's gaze and the location of the movable ashtray.</summary>
    public void SetConversationTargets(Vector3 otherEyes,Vector3 worldAshtray)
    {
        conversationEyes=otherEyes;
        ashtray=worldAshtray;
        hasConversationTargets=true;
    }

    public void WorkAtCounter(bool coffee,float cycle,float blend)
    {
        Vector3 grip=new Vector3(0,-.108f,.065f);
        Vector3 toolAxis=Quaternion.Euler(61,0,0)*Vector3.up;
        Vector3 tip=grip-toolAxis*(coffee?.099f:.091f);
        Vector3 target=coffee?KinseiWorld.CoffeeCupCentre+new Vector3(Mathf.Sin(cycle)*.020f,0,Mathf.Cos(cycle)*.020f):KinseiWorld.RadioTrimSocket;
        Quaternion pose=Quaternion.LookRotation(Vector3.up,Vector3.back);
        pose=Quaternion.FromToRotation(pose*toolAxis,Vector3.up)*pose;
        float turn=coffee?Mathf.Sin(cycle)*9f:Mathf.Sin(cycle)*32f;
        pose=Quaternion.AngleAxis(turn,Vector3.up)*pose;
        ReachPalm(ra,re,rh,target,pose*Vector3.forward,-(pose*Vector3.up),blend,transform.right,tip);
        if(rightHandRenderer)rightHandRenderer.SetBlendShapeWeight(0,coffee?57f:69f);
    }

    void ReachPalm(Transform shoulder,Transform elbow,Transform wrist,Vector3 palm,Vector3 normal,
        Vector3 fingers,float weight,Vector3 elbowOut)
    {
        ReachPalm(shoulder,elbow,wrist,palm,normal,fingers,weight,elbowOut,V(0,-.077f,.013f));
    }

    void ReachPalm(Transform shoulder,Transform elbow,Transform wrist,Vector3 palm,Vector3 normal,
        Vector3 fingers,float weight,Vector3 elbowOut,Vector3 handContact)
    {
        Quaternion orientation=Quaternion.LookRotation(normal,-fingers);
        Vector3 contactOffset=orientation*handContact;
        SolveLimb(shoulder,elbow,wrist,palm-contactOffset,-transform.up+elbowOut*.44f,weight);
        wrist.rotation=Quaternion.Slerp(wrist.rotation,orientation,weight);
    }

    static void SolveLimb(Transform upper,Transform lower,Transform end,Vector3 target,Vector3 pole,float weight)
    {
        if(weight<=0) return;
        Vector3 start=upper.position, delta=target-start;
        if(delta.sqrMagnitude<.000001f)return;
        float a=Vector3.Distance(start,lower.position), b=Vector3.Distance(lower.position,end.position);
        float d=Mathf.Clamp(delta.magnitude,Mathf.Abs(a-b)+.001f,a+b-.001f);
        Vector3 direction=delta.normalized;
        Vector3 bend=Vector3.ProjectOnPlane(pole,direction).normalized;
        if(bend.sqrMagnitude<.01f)
            bend=Vector3.ProjectOnPlane(upper.right,direction).normalized;
        float cosine=Mathf.Clamp((a*a+d*d-b*b)/(2*a*d),-1,1);
        Vector3 middle=start+direction*(cosine*a)+bend*(Mathf.Sqrt(1-cosine*cosine)*a);
        Vector3 clamped=start+direction*d;
        Quaternion upperRotation=Quaternion.FromToRotation(lower.position-start,middle-start)*upper.rotation;
        upper.rotation=Quaternion.Slerp(upper.rotation,upperRotation,weight);
        Quaternion lowerRotation=Quaternion.FromToRotation(end.position-lower.position,clamped-lower.position)*lower.rotation;
        lower.rotation=Quaternion.Slerp(lower.rotation,lowerRotation,weight);
    }

    void UpgradeSkin(bool boss,bool makabe,bool kaji,int variant)
    {
        bool brother=roleName=="brother";
        bool young=brother || roleName=="tatsu" || (!boss && !makabe && !kaji && variant%3==1);
        bool elder=boss || kaji;
        string shape=elder?"Elder":young?"Young":"Adult";
        string resident=roleName=="resident" && variant==0?"Sumiko":roleName=="resident" && variant==4?"Murase":null;
        string folder=resident!=null?"KinseiResidents/":"KinseiCast/";
        if(resident!=null)shape=resident;
        var faceResource=FindPart("Head"+shape,folder);
        if(faceResource==null)
        {
            BuildFallbackFace(boss,kaji);
            BuildFallbackHand(lh,-1);
            BuildFallbackHand(rh,1);
            return;
        }
        realisticSkin=new Material(Shader.Find("Standard (Specular setup)"));
        realisticSkin.name="CC0 human skin";
        realisticSkin.color=boss?new Color(.79f,.77f,.76f):kaji?new Color(.82f,.81f,.82f)
            :makabe?new Color(.73f,.71f,.72f):new Color(.82f,.80f,.81f);
        realisticSkin.mainTexture=resident!=null?Resources.Load<Texture2D>(folder+"Skin"+resident):elder
            ? Resources.Load<Texture2D>("KinseiCast/SkinElderNeutral") ?? Resources.Load<Texture2D>("KinseiCast/SkinElder")
            : Resources.Load<Texture2D>("KinseiCast/SkinYoungStyled") ?? Resources.Load<Texture2D>("KinseiCast/SkinYoung");
        realisticSkin.SetTexture("_BumpMap",Resources.Load<Texture2D>("KinseiCast/SkinNormal"));
        realisticSkin.SetFloat("_BumpScale",elder?.27f:.34f);
        realisticSkin.EnableKeyword("_NORMALMAP");
        // A dielectric skin highlight. The source specular atlas encodes legacy strength near 0.5.
        realisticSkin.SetColor("_SpecColor",new Color(.036f,.033f,.031f));
        realisticSkin.SetFloat("_Glossiness",.29f);
        Mesh face=faceResource.sharedMesh;
        bool reflectZ=-face.bounds.min.z>face.bounds.max.z;
        detailJaw=Joint("Deforming mandible",head,V(0,elder?.035f:.046f,-.033f));
        float lipLine=resident!=null?.035f:elder?.015f:young?.030f:.025f;
        Vector3 socketCenter=resident!=null?V(.0280f,.1106f,.0824f):elder?ElderEye:young?YoungEye:AdultEye;
        localEyeCenter=V(0,socketCenter.y,socketCenter.z+.010f);
        faceRenderer=ImportSkin(faceResource,head,chest,V(1,1,reflectZ?-1:1),Vector3.zero,detailJaw,lipLine,socketCenter.y);
        foreach(var wrist in new[]{lh,rh})
        {
            bool left=wrist==lh;
            var source=FindPart(left?"HandL":"HandR");
            if(source==null)
            {
                BuildFallbackHand(wrist,left?-1:1);
                continue;
            }
            Mesh hand=source.sharedMesh;
            float fingertipX=0;
            foreach(Vector3 position in hand.vertices)
                if(position.y<-.186f)fingertipX+=position.x;
            bool reflectX=left?fingertipX<0:fingertipX>0;
            var anatomicallyAligned=ImportSkin(source,wrist,wrist.parent,V(reflectX?-.82f:.82f,.82f,reflectZ?-.82f:.82f),
                V(0,.013f,0),handYaw:left?-73:73);
            if(left)leftHandRenderer=anatomicallyAligned;
            else rightHandRenderer=anatomicallyAligned;
        }

        string style=brother?"Brother":shape;
        var cap=FindPart("Hair"+style,folder);
        if(cap!=null)
        {
            if(resident!=null)hair.color=resident=="Sumiko"?new Color(.82f,.80f,.78f):new Color(.56f,.51f,.49f);
            hair.mainTexture=Resources.Load<Texture2D>(folder+"Hair"+style+"Grain");
            if(hair.mainTexture)
            {
                hair.SetOverrideTag("RenderType","TransparentCutout");
                hair.SetFloat("_Mode",1);
                hair.SetFloat("_Cutoff",.48f);
                hair.EnableKeyword("_ALPHATEST_ON");
                hair.renderQueue=(int)UnityEngine.Rendering.RenderQueue.AlphaTest;
            }
            var hairMesh=CopyPart(cap,V(1,1,reflectZ?-1:1),Vector3.zero);
            MeshObject("Fitted swept hair",head,hair,hairMesh);
        }
        else
        {
            Shape("Coiffure",head,hair,new[]{R(.133f,.073f,.073f),R(.181f,.074f,.087f),
                R(.220f,.053f,.053f),R(.234f,.008f,.012f)},28);
        }

        eye.mainTexture=Resources.Load<Texture2D>("KinseiCast/EyeGlobe");
        eye.color=new Color(.84f,.82f,.80f);
        eye.SetFloat("_Glossiness",.41f);
        for(int side=-1;side<=1;side+=2)
        {
            Transform socket=new GameObject(side<0?"Left eye":"Right eye").transform;
            socket.SetParent(head,false);
            socket.localPosition=V(side*socketCenter.x,socketCenter.y,socketCenter.z);
            socket.localRotation=Quaternion.Euler(0,side*7,0);
            eyes[(side+1)/2]=socket;
            MeshObject("Cornea and iris",socket,eye,EyeCap(elder?.0128f:.0136f));
        }
        if(boss)
        {
            var whisker=Mat("Whisker shadow",new Color(.09f,.06f,.045f),.1f);
            // The boss wears two swept sections between nose and upper lip.
            for(int side=-1;side<=1;side+=2)
            {
                Transform w=Oval("Moustache",head,whisker,V(side*.014f,.026f,.102f),
                    V(.015f,.003f,.0025f));
                w.localRotation=Quaternion.Euler(0,side*22,side*-12);
            }
            extraMaterials.Add(whisker);
        }
    }

    static Mesh EyeCap(float depth)
    {
        const int rings=8, segments=32;
        var vertices=new List<Vector3> {V(0,0,depth)};
        var uv=new List<Vector2> {new Vector2(.5f,.5f)};
        var triangles=new List<int>();
        for(int ring=1;ring<=rings;ring++)
        {
            float radial=(float)ring/rings;
            for(int i=0;i<segments;i++)
            {
                float theta=i*2*Mathf.PI/segments;
                float x=Mathf.Cos(theta)*radial,y=Mathf.Sin(theta)*radial;
                vertices.Add(V(x*.015f,y*.011f,depth*Mathf.Sqrt(1-radial*radial)));
                uv.Add(new Vector2(.5f+x*.5f,.5f+y*.5f));
                int a=1+(ring-1)*segments+i,b=1+(ring-1)*segments+(i+1)%segments;
                if(ring==1)triangles.AddRange(new[]{0,a,b});
                else triangles.AddRange(new[]{a-segments,a,b,b-segments,a-segments,b});
            }
        }
        var mesh=new Mesh {name="Inset eye globe"};
        mesh.SetVertices(vertices);
        mesh.SetUVs(0,uv);
        mesh.SetTriangles(triangles,0);
        mesh.RecalculateNormals();
        mesh.RecalculateBounds();
        return mesh;
    }

    static MeshFilter FindPart(string name,string folder="KinseiCast/")
    {
        GameObject model=Resources.Load<GameObject>(folder+name);
        if(model==null) return null;
        MeshFilter filter=model.GetComponentInChildren<MeshFilter>(true);
        return filter && filter.sharedMesh && filter.sharedMesh.isReadable?filter:null;
    }

    static Mesh CopyPart(MeshFilter source,Vector3 scale,Vector3 offset,float yaw=0)
    {
        var mesh=Instantiate(source.sharedMesh);
        var vertices=mesh.vertices;
        var normals=mesh.normals;
        Matrix4x4 transform=Matrix4x4.TRS(offset,Quaternion.Euler(0,yaw,0),scale) *
            source.transform.localToWorldMatrix;
        Matrix4x4 normalTransform=transform.inverse.transpose;
        for(int i=0;i<vertices.Length;i++)vertices[i]=transform.MultiplyPoint3x4(vertices[i]);
        for(int i=0;i<normals.Length;i++)normals[i]=normalTransform.MultiplyVector(normals[i]).normalized;
        mesh.vertices=vertices;
        mesh.normals=normals;
        if(transform.determinant<0)
        {
            for(int sub=0;sub<mesh.subMeshCount;sub++)
            {
                int[] indices=mesh.GetTriangles(sub);
                for(int i=0;i<indices.Length;i+=3)(indices[i],indices[i+2])=(indices[i+2],indices[i]);
                mesh.SetTriangles(indices,sub,false);
            }
        }
        mesh.RecalculateBounds();
        mesh.RecalculateTangents();
        return mesh;
    }

    SkinnedMeshRenderer ImportSkin(MeshFilter source,Transform parent,Transform anchor,Vector3 scale,
        Vector3 offset,Transform mandible=null,float lipLine=0,float eyeLine=0,float handYaw=0)
    {
        bool face=mandible!=null;
        Mesh mesh=CopyPart(source,scale,offset,handYaw);
        if(!face)AddFingerCurl(mesh);
        var part=new GameObject(face?"Fitted head":"Anatomical hand").transform;
        part.SetParent(parent,false);
        var weights=new BoneWeight[mesh.vertexCount];
        var vertices=mesh.vertices;
        if(face)
        {
            for(int i=0;i<vertices.Length;i++)
            {
                Vector3 point=vertices[i];
                float tuck=1-Ease(-.035f,-.016f,point.y);
                if(tuck<=0)continue;
                Vector2 radial=new Vector2(point.x,point.z+.014f);
                radial=Vector2.Lerp(radial,Vector2.ClampMagnitude(radial,.061f),tuck);
                vertices[i]=V(radial.x,point.y-.020f*tuck,radial.y-.014f);
            }
            mesh.vertices=vertices;
            mesh.RecalculateBounds();
            mesh.RecalculateTangents();
            AddBlink(mesh,vertices,eyeLine);
            if(roleName=="kaji" || roleName=="brother")AddInnerBrowLift(mesh,vertices,eyeLine);
        }
        for(int i=0;i<weights.Length;i++)
        {
            float follow=face?Mathf.SmoothStep(0,1,Mathf.InverseLerp(-.036f,.028f,vertices[i].y))
                :Mathf.SmoothStep(0,1,Mathf.InverseLerp(.010f,-.045f,vertices[i].y));
            float jawInfluence=face?Ease(.028f,.080f,vertices[i].z)*(1-Ease(lipLine-.009f,lipLine+.004f,vertices[i].y))*
                Ease(-.026f,-.008f,vertices[i].y):0;
            weights[i]=new BoneWeight {boneIndex0=0,weight0=follow*(1-jawInfluence),
                boneIndex1=1,weight1=(1-follow)*(1-jawInfluence),boneIndex2=face?2:0,weight2=jawInfluence};
        }
        mesh.boneWeights=weights;
        Transform[] bones=face?new[]{parent,anchor,mandible}:new[]{parent,anchor};
        var bind=new Matrix4x4[bones.Length];
        for(int i=0;i<bind.Length;i++)bind[i]=bones[i].worldToLocalMatrix*part.localToWorldMatrix;
        mesh.bindposes=bind;
        var skinned=part.gameObject.AddComponent<SkinnedMeshRenderer>();
        skinned.sharedMesh=mesh;skinned.bones=bones;
        skinned.rootBone=parent;skinned.sharedMaterial=realisticSkin;
        skinned.quality=face?SkinQuality.Bone4:SkinQuality.Bone2;
        skinned.localBounds=new Bounds(Vector3.zero,Vector3.one);
        return skinned;
    }

    static void AddBlink(Mesh face,Vector3[] vertices,float eyeLine)
    {
        var delta=new Vector3[vertices.Length];
        for(int i=0;i<vertices.Length;i++)
        {
            Vector3 point=vertices[i];
            float across=1-Ease(.009f,.020f,Mathf.Abs(Mathf.Abs(point.x)-.029f));
            float depth=Ease(.072f,.089f,point.z);
            float height=point.y-eyeLine;
            float outline=1-Ease(.008f,.019f,Mathf.Abs(height));
            float closing=height>0?.99f:.76f;
            delta[i]=V(0,-height*across*depth*outline*closing,0);
        }
        face.AddBlendShapeFrame("Blink",100,delta,null,null);
    }

    static void AddInnerBrowLift(Mesh face,Vector3[] vertices,float eyeLine)
    {
        var raised=new Vector3[vertices.Length];
        for(int i=0;i<vertices.Length;i++) {
            Vector3 p=vertices[i];
            float horizontal=1-Ease(.006f,.038f,Mathf.Abs(Mathf.Abs(p.x)-.020f));
            float height=p.y-eyeLine;
            float band=Ease(.005f,.021f,height)*(1-Ease(.029f,.053f,height));
            float amount=horizontal*band*Ease(.053f,.080f,p.z);
            raised[i]=new Vector3(0,p.x<0?.0048f:.0035f,.0008f)*amount;
        }
        face.AddBlendShapeFrame("Inner brow lift",100,raised,null,null);
    }

    static void AddFingerCurl(Mesh hand)
    {
        var vertices=hand.vertices;
        var normals=hand.normals;
        var delta=new Vector3[vertices.Length];
        var deltaNormals=new Vector3[vertices.Length];
        for(int i=0;i<vertices.Length;i++)
        {
            Vector3 point=vertices[i];
            float finger=Ease(.077f,.139f,-point.y);
            if(finger<=0)continue;
            var knuckle=V(point.x,-.077f,Mathf.Lerp(point.z,.003f,finger*.33f));
            Quaternion bend=Quaternion.Euler(-91*finger,0,0);
            delta[i]=knuckle+bend*(point-knuckle)-point;
            deltaNormals[i]=bend*normals[i]-normals[i];
        }
        hand.AddBlendShapeFrame("Finger curl",100,delta,deltaNormals,null);
    }

    void BuildSidearm()
    {
        sidearm=new GameObject("Fictional cinema prop").transform;
        sidearm.SetParent(rh,false);
        sidearm.localPosition=V(0,-.089f,.029f);
        sidearm.localRotation=Quaternion.Euler(0,-30,0);
        propMetal=Mat("Blued cinema prop",new Color(.051f,.057f,.066f),.48f);
        // Solid abstract silhouette for the interactive pose.
        Oval("Solid prop grip",sidearm,propMetal,V(0,0,-.034f),V(.016f,.025f,.046f));
        Shape("Solid prop body",sidearm,propMetal,new[]{R(-.105f,.013f,.016f),
            R(-.096f,.017f,.020f),R(.018f,.017f,.022f),R(.025f,.014f,.017f)},12)
            .localPosition=V(0,0,.003f);
        sidearm.gameObject.SetActive(false);
    }
    void OnDestroy()
    {
        if(body!=null) { var meshes=new HashSet<Mesh>(); foreach(var r in body.GetComponentsInChildren<SkinnedMeshRenderer>(true)) if(r.sharedMesh!=null) meshes.Add(r.sharedMesh); foreach(var f in body.GetComponentsInChildren<MeshFilter>(true)) if(f.sharedMesh!=null) meshes.Add(f.sharedMesh); foreach(var m in meshes) Destroy(m); }
        foreach(var material in new[]{skin,cloth,dark,shirt,tie,hair,eye,iris,lip,metal,collar,realisticSkin,propMetal}) if(material!=null)Destroy(material);
        foreach(var material in extraMaterials)Destroy(material);
    }
    // Merge all surfaces attached to a bone by material: facial details remain modeled
    // while avoiding a draw call per eyelid, finger or lapel.
    static void MergeSurfaces(Transform bone)
    {
        var children=new List<Transform>(); foreach(Transform child in bone) children.Add(child);
        foreach(var child in children) if(child.GetComponent<MeshFilter>()==null) MergeSurfaces(child);
        var groups=new Dictionary<Material,List<MeshFilter>>();
        foreach(var child in children) {var f=child.GetComponent<MeshFilter>(); if(f==null||!child.gameObject.activeSelf)continue;var m=child.GetComponent<MeshRenderer>().sharedMaterial;if(!groups.ContainsKey(m))groups[m]=new List<MeshFilter>();groups[m].Add(f);}
        foreach(var group in groups) {
            if(group.Value.Count<2)continue;
            var combine=new CombineInstance[group.Value.Count];
            for(int i=0;i<combine.Length;i++) {var f=group.Value[i];combine[i]=new CombineInstance {mesh=f.sharedMesh,transform=Matrix4x4.TRS(f.transform.localPosition,f.transform.localRotation,f.transform.localScale)};}
            var mesh=new Mesh {name=bone.name+" "+group.Key.name};mesh.CombineMeshes(combine,true,true);
            MeshObject(mesh.name,bone,group.Key,mesh);
            foreach(var f in group.Value) { Destroy(f.sharedMesh); f.gameObject.SetActive(false); Destroy(f.gameObject); }
        }
    }
    static Vector3 V(float x,float y,float z) { return new Vector3(x,y,z); }
    static Vector4 R(float y,float x,float z) { return new Vector4(x,y,z,0); }
    Transform Joint(string label,Transform parent,Vector3 position) { var o=new GameObject(label).transform; o.SetParent(parent,false); o.localPosition=position; joints.Add(o); rests[o]=position; return o; }
    static Material Mat(string label,Color color,float smooth) { var m=new Material(Shader.Find("Standard")); m.name=label; m.color=color; m.SetFloat("_Glossiness",smooth); return m; }
    static Transform Oval(string label,Transform parent,Material mat,Vector3 pos,Vector3 size)
    {
        var rings=new Vector4[13]; for(int j=0;j<13;j++) { float a=Mathf.PI*j/12; rings[j]=new Vector4(Mathf.Max(.0001f,Mathf.Sin(a)*size.x),Mathf.Cos(a)*size.y,Mathf.Max(.0001f,Mathf.Sin(a)*size.z),0); }
        var o=Ring(label,parent,mat,rings,20); o.localPosition=pos; return o;
    }
    static Transform Shape(string label,Transform parent,Material mat,Vector4[] r,int n) { return Ring(label,parent,mat,r,n); }
    static Transform Ring(string label,Transform parent,Material mat,Vector4[] rings,int n)
    {
        var v=new List<Vector3>(); var uv=new List<Vector2>(); var tri=new List<int>();
        for(int j=0;j<rings.Length;j++) for(int i=0;i<=n;i++) { float a=i*Mathf.PI*2/n; v.Add(V(Mathf.Cos(a)*rings[j].x,rings[j].y,Mathf.Sin(a)*rings[j].z)); uv.Add(new Vector2((float)i/n,rings[j].y*1.6f)); }
        for(int j=0;j<rings.Length-1;j++) for(int i=0;i<n;i++) { int a=j*(n+1)+i,b=a+n+1; tri.Add(a);tri.Add(a+1);tri.Add(b);tri.Add(b);tri.Add(a+1);tri.Add(b+1); }
        // Cap open tailored surfaces, using face-normal winding independent of ring ordering.
        int bottom=v.Count; v.Add(V(0,rings[0].y,0)); int top=v.Count; v.Add(V(0,rings[rings.Length-1].y,0)); uv.Add(Vector2.zero);uv.Add(Vector2.one);
        for(int i=0;i<n;i++) {tri.Add(bottom);tri.Add(i+1);tri.Add(i);int k=(rings.Length-1)*(n+1)+i;tri.Add(top);tri.Add(k);tri.Add(k+1);}
        // Rings are normally written bottom to top, but limbs descend; reverse those meshes.
        if(rings[0].y<rings[rings.Length-1].y) for(int i=0;i<tri.Count;i+=3) {int q=tri[i];tri[i]=tri[i+2];tri[i+2]=q;}
        var mesh=new Mesh { name=label }; mesh.SetVertices(v);mesh.SetUVs(0,uv);mesh.SetTriangles(tri,0);mesh.RecalculateNormals();
        var normals=mesh.normals;
        for(int j=0;j<rings.Length;j++)
        {
            int a=j*(n+1), b=a+n;
            normals[a]=normals[b]=(normals[a]+normals[b]).normalized;
        }
        mesh.normals=normals;
        mesh.RecalculateTangents();
        mesh.RecalculateBounds();
        return MeshObject(label,parent,mat,mesh);
    }
    static void Patch(string label,Transform parent,Material mat,Vector3[] points)
    {
        var indices=new List<int>();
        for(int i=1;i<points.Length-1;i++)
        {
            Vector3 middle=(points[0]+points[i]+points[i+1])/3;
            Vector3 normal=Vector3.Cross(points[i]-points[0],points[i+1]-points[0]);
            bool reverse=Vector3.Dot(normal,V(middle.x*.2f,0,middle.z))<0;
            indices.Add(0);
            indices.Add(reverse?i+1:i);
            indices.Add(reverse?i:i+1);
        }
        var mesh=new Mesh {name=label};mesh.vertices=points;
        var uv=new Vector2[points.Length];
        for(int i=0;i<points.Length;i++)uv[i]=new Vector2(points[i].x*2,points[i].y*1.6f);
        mesh.uv=uv;
        mesh.triangles=indices.ToArray();mesh.RecalculateNormals();mesh.RecalculateTangents();mesh.RecalculateBounds();MeshObject(label,parent,mat,mesh);
    }
    static void Stitch(string label,Transform parent,Material material,float width,params Vector3[] path)
    {
        var points=new Vector3[path.Length*2];
        var indices=new int[(path.Length-1)*6];
        for(int i=0;i<path.Length;i++)
        {
            points[i*2]=path[i]-Vector3.right*width*.5f;
            points[i*2+1]=path[i]+Vector3.right*width*.5f;
            if(i>=path.Length-1)continue;
            int a=i*2, t=i*6;
            indices[t]=a;indices[t+1]=a+2;indices[t+2]=a+1;
            indices[t+3]=a+1;indices[t+4]=a+2;indices[t+5]=a+3;
        }
        var mesh=new Mesh {name=label,vertices=points,triangles=indices};
        mesh.RecalculateNormals();
        MeshObject(label,parent,material,mesh);
    }

    static void HalfCollar(string label,Transform parent,Material material,float halfWidth,float depth,float bottom,float top)
    {
        for(int side=-1;side<=1;side+=2)
            for(int section=0;section<12;section++)
            {
                float a=section*Mathf.PI/12, b=(section+1)*Mathf.PI/12;
                Vector3 lowA=V(side*Mathf.Sin(a)*halfWidth*1.20f,bottom,-Mathf.Cos(a)*depth*1.2f-.01f);
                Vector3 lowB=V(side*Mathf.Sin(b)*halfWidth*1.20f,bottom,-Mathf.Cos(b)*depth*1.2f-.01f);
                Vector3 highA=V(side*Mathf.Sin(a)*halfWidth,Mathf.Lerp(top,top-.027f,a/Mathf.PI),-Mathf.Cos(a)*depth-.013f);
                Vector3 highB=V(side*Mathf.Sin(b)*halfWidth,Mathf.Lerp(top,top-.027f,b/Mathf.PI),-Mathf.Cos(b)*depth-.013f);
                Patch(label,parent,material,new[]{lowA,lowB,highB,highA});
            }
    }
    static Transform MeshObject(string label,Transform parent,Material mat,Mesh mesh) {var o=new GameObject(label);o.transform.SetParent(parent,false);o.AddComponent<MeshFilter>().sharedMesh=mesh;var r=o.AddComponent<MeshRenderer>();r.sharedMaterial=mat;return o.transform;}
}


