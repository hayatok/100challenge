using UnityEngine;

public sealed partial class KinseiWorld
{
    readonly Light[] streetPracticalLights=new Light[3];
    Material canalSurface, pierDiffuser, benchTube, alignmentPhosphor;

    // Geometry in the same coordinates as the existing bridge post caps, CRT masks and canopy.
    static void MakeStreetFixtures(NightGeometry metal,NightGeometry opal,NightGeometry tube,NightGeometry screens)
    {
        foreach(float x in new[]{-33.77f,-27.92f})foreach(float z in new[]{-12.93f,-7.47f})
        {
            metal.Block(new Vector3(x,1.115f,z),new Vector3(.19f,.05f,.22f));
            opal.Block(new Vector3(x,1.285f,z),new Vector3(.17f,.29f,.18f));
            foreach(int dx in new[]{-1,1})foreach(int dz in new[]{-1,1})
                metal.Block(new Vector3(x+.086f*dx,1.285f,z+.091f*dz),new Vector3(.019f,.31f,.02f));
            metal.Block(new Vector3(x,1.301f,z),new Vector3(.205f,.022f,.21f));
            metal.Block(new Vector3(x,1.452f,z),new Vector3(.26f,.049f,.27f));
            metal.Block(new Vector3(x,1.490f,z),new Vector3(.17f,.040f,.18f));
        }
        // Two enamel troughs beneath the front slats. The model and light occupy the same ceiling bay.
        foreach(float x in new[]{25.64f,27.75f})
        {
            metal.Block(new Vector3(x,2.767f,-13.49f),new Vector3(1.08f,.10f,.23f));
            tube.Tube(new Vector3(x-.46f,2.697f,-13.49f),new Vector3(x+.46f,2.697f,-13.49f),.024f);
            foreach(int side in new[]{-1,1})
                metal.Block(new Vector3(x+.465f*side,2.711f,-13.49f),new Vector3(.052f,.09f,.11f));
        }
        for(int i=0;i<3;i++)
        {
            float x=25.24f+1.27f*i,h=.49f+.08f*i;
            screens.Pane(new Vector3(x-.06f,.78f+h*.5f,-13.368f),
                Vector3.right*.248f,Vector3.up*((h-.17f)*.5f),i);
            for(int row=0;row<4;row++)
                metal.Block(new Vector3(x+.296f,.935f+row*.025f,-13.397f),new Vector3(.132f,.008f,.055f));
        }
    }

    void BuildStreetFixtures(Material water,Material zinc)
    {
        var owner=nightAssets;
        var frames=new NightGeometry();var opal=new NightGeometry();var tube=new NightGeometry();var crt=new NightGeometry();
        MakeStreetFixtures(frames,opal,tube,crt);
        pierDiffuser=owner.Keep(Mat("橋詰の乳白ガラス","#B5A388",.07f,.48f,1));
        benchTube=owner.Keep(Mat("修理台の直管","#B8C6BB",.05f,.39f,1));
        alignmentPhosphor=owner.Keep(Mat("店先の調整信号","#83988C",.06f,.52f,1));
        var pattern=Resources.Load<Texture2D>("KinseiStreetLights/BenchPatterns");
        alignmentPhosphor.mainTexture=pattern;alignmentPhosphor.SetTexture("_EmissionMap",pattern);
        frames.Upload(owner.Root,zinc,owner);opal.Upload(owner.Root,pierDiffuser,owner);
        tube.Upload(owner.Root,benchTube,owner);crt.Upload(owner.Root,alignmentPhosphor,owner);
        var shader=Resources.Load<Shader>("KinseiStreetLights/Canal");
        if(shader){water.shader=shader;canalSurface=water;}
        // Each near/far pair shares one unshadowed local bounce. Positioned inside opposite corner housings.
        streetPracticalLights[0]=LightAt("橋詰・東岸",new Vector3(-27.92f,1.31f,-12.93f),new Color(1,.77f,.50f),2.45f,7.4f);
        streetPracticalLights[1]=LightAt("橋詰・西岸",new Vector3(-33.77f,1.31f,-7.47f),new Color(1,.77f,.50f),2.45f,7.4f);
        var lamp=streetPracticalLights[2]=LightAt("修理台の反射笠",new Vector3(26.75f,2.69f,-13.49f),
            new Color(.85f,.95f,.86f),3.0f,5.15f);
        lamp.type=LightType.Spot;lamp.spotAngle=116;lamp.innerSpotAngle=75;
        lamp.transform.LookAt(transform.TransformPoint(new Vector3(26.75f,.81f,-13.56f)));
        SetStreetFixtureDay(false);
    }

    void SetStreetFixtureDay(bool day)
    {
        if(!pierDiffuser)return;
        foreach(var lamp in streetPracticalLights)if(lamp)lamp.enabled=!day;
        pierDiffuser.SetColor("_EmissionColor",day?Color.black:new Color(.90f,.63f,.31f));
        benchTube.SetColor("_EmissionColor",day?Color.black:new Color(.67f,.82f,.69f));
        alignmentPhosphor.SetColor("_EmissionColor",day?new Color(.11f,.13f,.11f):new Color(.54f,.75f,.61f));
        if(canalSurface)canalSurface.SetFloat("_Dawn",day?1:0);
    }
}
