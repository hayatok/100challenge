using UnityEngine;

public sealed partial class KinseiWorld
{
    // The western bridge and bath have matching walkable surfaces in BuildWestBath.
    sealed class StreetEnd
    {
        public readonly NightGeometry stone = new NightGeometry(), sheet = new NightGeometry(),
            timber = new NightGeometry(), window = new NightGeometry(), road = new NightGeometry(),
            roof = new NightGeometry(), canal = new NightGeometry(), terrazzo = new NightGeometry();

        public void Block(NightGeometry g,float x,float y,float z,float w,float h,float d)
        { g.Block(new Vector3(x,y,z),new Vector3(w,h,d)); }
        public void Pipe(NightGeometry g,float x,float y,float z,float xx,float yy,float zz,float r)
        { g.Tube(new Vector3(x,y,z),new Vector3(xx,yy,zz),r); }

        // Pitched zinc sheets with standing seams, eaves and rainwater pipes.
        void Roof(float x,float y,float z,float w,float d,float rise)
        {
            foreach(int side in new[]{-1,1})
            {
                var span=new Vector3(0,-rise,side*d*.5f);
                var centre=new Vector3(x,y+rise*.5f,z+side*d*.25f);
                roof.Pane(centre,Vector3.right*(-side*w*.5f),span*.5f,0);
                for(float u=-w/2+.18f;u<w/2;u+=.58f)
                    Pipe(sheet,x+u,y+rise,z,x+u,y,z+side*d*.5f,.017f);
                Pipe(sheet,x-w/2,y,z+side*d/2,x+w/2,y,z+side*d/2,.059f);
            }
            foreach(int end in new[]{-1,1})
            {
                float gx=x+end*(w-.58f)*.5f;
                stone.Gable(new Vector3(gx,y-.07f,z),end,d-.68f,rise+.07f);
            }
            Pipe(sheet,x-w/2,y+rise,z,x+w/2,y+rise,z,.081f);
            Pipe(sheet,x+w/2-.12f,y,z+d/2,x+w/2-.12f,.16f,z+d/2,.052f);
        }

        public void House(float x,float z,float w,float d,int floors,int face,int variation,bool bath=false)
        {
            float h=2.8f*floors, front=z+d*.5f*face;
            if(bath)
            {
                // Preserve the original upper house over the recessed ground-floor vestibule.
                Block(stone,x,(h+2.8f)/2,z,w,h-2.8f,d);
                Block(stone,x,1.4f,z-1.16f,w,2.8f,d-2.32f);
            }
            else Block(stone,x,h/2,z,w,h,d);
            Roof(x,h+.06f,z,w+.58f,d+.68f,.65f+.16f*(variation%3));
            int bays=Mathf.Max(2,(int)(w/2.65f));
            for(int level=0;level<floors;level++)
            {
                if(bath && level==0)continue;
                float y=1.42f+level*2.8f;
                for(int b=0;b<bays;b++)
                {
                    float u=x+w*((b+.5f)/bays-.5f);
                    BuildDomesticWindow(timber,sheet,window,new Vector3(u,y,front),1.66f,1.23f,face,(variation+b+level)%4);
                    if(level==0 || (b+level+variation)%3!=0)continue;
                    float bal=front+face*.79f;
                    Block(stone,u,y-.74f,bal-face*.32f,2.16f,.12f,.91f);
                    Pipe(sheet,u-1.02f,y+.15f,bal,u+1.02f,y+.15f,bal,.028f);
                    for(int j=0;j<8;j++)Pipe(sheet,u-1.0f+j*.285f,y-.69f,bal,u-1.0f+j*.285f,y+.15f,bal,.017f);
                }
            }
            // Gable glazing faces approaching pedestrians looking along X.
            int end=x<0?1:-1;
            for(int level=0;level<floors;level++)
            {
                float ex=x+end*(w/2+.06f), yy=1.5f+level*2.8f;
                Block(timber,ex,yy,z,.12f,1.52f,2.22f);
                window.Pane(new Vector3(ex+end*.08f,yy,z),Vector3.back*end,Vector3.up*.64f,(variation+level)%4);
                Block(timber,ex+end*.11f,yy,z,.06f,1.36f,.07f);
                Block(sheet,ex+end*.14f,yy-.74f,z,.42f,.09f,2.35f);
            }
        }

        public void West()
        {
            // Two embankments flank the open canal. The road itself spans the gap.
            Block(road,-25.0f,-.18f,-8.6f,6.2f,.29f,24);
            Block(road,-46.8f,-.19f,-8.6f,26.4f,.30f,24);
            Block(canal,-30.85f,-1.47f,-8.6f,5.9f,.26f,24);
            for(int bank=0;bank<2;bank++)
            {
                float x=bank==0?-28.1f:-33.6f;
                Block(stone,x,-.81f,-8.6f,.32f,1.60f,24);
                for(int i=0;i<23;i++)
                    Block(sheet,x+(bank==0?-.18f:.18f),-.57f,-19.65f+i,.055f,.55f,.075f);
            }
            Block(stone,-30.85f,-.23f,-10.2f,6.15f,.38f,5.65f);
            Block(road,-30.85f,-.048f,-10.2f,6.18f,.074f,5.48f);
            foreach(float z in new[]{-12.93f,-7.47f})
            {
                terrazzo.Block(new Vector3(-30.85f,.065f,z),new Vector3(6.2f,.15f,.31f),.20f);
                for(int j=0;j<7;j++)
                {
                    float x=-33.77f+j*.975f;
                    terrazzo.Block(new Vector3(x,.56f,z),new Vector3(.19f,.98f,.25f),.20f);
                    Block(sheet,x,1.055f,z,.25f,.072f,.31f);
                }
                for(int j=0;j<3;j++)Pipe(sheet,-33.80f,.30f+j*.33f,z,-27.89f,.30f+j*.33f,z,.045f);
            }
            House(-25.1f,-3.6f,4.1f,4.2f,2,-1,0);
            House(-41.4f,-3.3f,12.8f,6.1f,3,-1,1);
            House(-55.4f,-10.8f,8.1f,8.3f,4,1,3);
            // Laundry rails on the maisonette's recessed side, visible above the bridge.
            Pipe(sheet,-45.3f,5.2f,-6.95f,-41.7f,5.2f,-6.95f,.028f);
            for(int j=0;j<3;j++)
            {
                float xx=-45.0f+j*.88f, h=.59f+.10f*j;
                Block(j==1?roof:stone,xx,5.18f-h*.5f,-6.95f,.55f,h,.036f);
                Block(timber,xx-.18f,5.21f,-6.95f,.036f,.075f,.07f);
            }
            // Fire stair at the west tenement's east end, backed by an external landing.
            for(int i=0;i<16;i++)
                Block(sheet,-34.27f,.16f+i*.17f,-19.4f+i*.24f,.96f,.10f,.27f);
            foreach(float side in new[]{-34.70f,-33.84f})
                Pipe(sheet,side,.105f,-19.48f,side,2.655f,-15.88f,.039f);
            Pipe(sheet,-33.82f,.98f,-19.4f,-33.82f,3.53f,-15.8f,.034f);
        }

        public void East()
        {
            Block(road,40.92f,-.18f,-8.6f,37.97f,.29f,24);
            House(27.1f,-16.98f,8.0f,5.4f,2,1,3);
            House(26.6f,-3.96f,7.4f,5.7f,2,-1,1);
            House(38.5f,-15.9f,11.8f,6.1f,2,1,0);
            House(40.6f,-2.6f,12.6f,7.1f,2,-1,2);
            House(53.4f,-9.4f,8.5f,7.3f,3,-1,1);
            // Repair counter and CRT cabinets under a slatted shop canopy.
            float fx=26.75f;
            Block(timber,fx,.70f,-13.72f,4.6f,.14f,.84f);
            foreach(float dx in new[]{-2.05f,0f,2.05f})Block(timber,fx+dx,.32f,-13.72f,.09f,.65f,.60f);
            for(int j=0;j<3;j++)
            {
                float x=fx-1.51f+1.27f*j, h=.49f+.08f*j;
                Block(timber,x,.78f+h/2,-13.68f,.82f,h,.54f);
                Block(sheet,x-.06f,.78f+h/2,-13.397f,.55f,h-.14f,.05f);
                Block(roof,x+.30f,1.05f,-13.376f,.085f,.135f,.044f);
            }
            for(int j=0;j<21;j++)Block(j%3==0?sheet:roof,fx-2.82f+j*.28f,2.88f,-13.69f,.28f,.12f,1.48f);
            foreach(float dx in new[]{-2.78f,2.78f})
                Pipe(sheet,fx+dx,2.84f,-13.02f,fx+dx,2.12f,-14.28f,.032f);
            Block(timber,fx,3.26f,-14.19f,5.66f,.63f,.16f);
            // Bent extract stacks and weather hoods over the workshop's ridge.
            for(int j=0;j<3;j++)
            {
                float x=35.2f+j*2.6f;
                Pipe(sheet,x,5.75f,-15.8f,x,7.03f+j*.23f,-15.8f,.20f);
                Block(roof,x,7.15f+j*.23f,-15.8f,.70f,.13f,.68f);
            }
        }

        public void Feeds(int side)
        {
            for(int pole=0;pole<3;pole++)
            {
                float x=side*(24f+pole*11.7f), z=side<0?-6.7f:-12.85f;
                Pipe(timber,x,0,z,x,6.55f,z,.106f);
                Block(sheet,x,6.26f,z,.14f,.13f,1.28f);
                if(pole==2)continue;
                for(int cable=0;cable<3;cable++)
                {
                    float zz=z+(cable-1)*.43f;
                    for(int j=0;j<6;j++)
                    {
                        float a=j/6f,b=(j+1)/6f;
                        Pipe(timber,x+side*a*11.7f,6.40f-1.48f*a*(1-a),zz,
                            x+side*b*11.7f,6.40f-1.48f*b*(1-b),zz,.014f);
                    }
                }
            }
        }

        public void ClubNeighbours()
        {
            // Close the lots between the side walls of the cabaret and each end of the street.
            // The canal bed remains above this continuous lower ground, and the lifts are to the south.
            Block(road,0,-2.17f,1.6f,121,.32f,101);
            Block(road,-17.38f,-.15f,2.15f,9.96f,.25f,19.70f);
            Block(road,15.56f,-.15f,2.15f,13.20f,.25f,19.70f);
            House(-17.45f,-3.22f,8.45f,6.70f,2,-1,2);
            House(15.94f,-3.49f,10.55f,6.22f,3,-1,3);
            House(-16.65f,8.72f,7.0f,6.52f,3,-1,1);
            House(15.83f,9.22f,8.11f,5.75f,2,-1,0);
            for(int side=0;side<2;side++){
                float x=side==0?-17.45f:15.94f;
                float z=side==0?-6.57f:-6.60f;
                Block(timber,x,2.47f,z-.32f,4.08f,.13f,.95f);
                Block(sheet,x,2.34f,z-.74f,4.13f,.21f,.075f);
                Block(timber,x,1.05f,z-.11f,1.28f,2.11f,.11f);
                window.Pane(new Vector3(x,1.45f,z-.178f),Vector3.right*.51f,Vector3.up*.51f,side+1);
                Block(timber,x,.92f,z-.19f,1.09f,.043f,.05f);
                Block(sheet,x+.42f,1.12f,z-.227f,.038f,.26f,.046f);
                Block(stone,x,.052f,z-.40f,1.62f,.104f,.65f);
                Block(timber,x-2.34f,2.22f,z-.31f,.62f,.99f,.24f);
            }
        }
    }

    void BuildStreetEnds(Material lime,Material zinc,Material sash,Material home,Material distant)
    {
        var e=new StreetEnd();
        e.West(); e.East(); e.Feeds(-1); e.Feeds(1);e.ClubNeighbours();
        // A lower, continuous earth bed catches steep views beyond both skirts and the canal.
        foreach(int side in new[]{-1,1})
            e.Block(e.road,side*42f,-1.86f,-9.1f,40.25f,.40f,46f);
        var owner=nightAssets;
        // In command view the residents and vestibule stay visible beneath the upper apartments.
        var bathHouse=new StreetEnd();
        bathHouse.House(-39.2f,-17.15f,8.7f,5.3f,3,1,2,true);
        var upperBath=new GameObject("浴場の上階・指揮時断面").transform;
        upperBath.SetParent(owner.Root,false);overhead.Add(upperBath.gameObject);
        bathHouse.stone.Upload(upperBath,lime,owner);bathHouse.sheet.Upload(upperBath,zinc,owner);
        bathHouse.timber.Upload(upperBath,sash,owner);bathHouse.window.Upload(upperBath,home,owner);
        bathHouse.roof.Upload(upperBath,distant,owner);
        var water=owner.Keep(Mat("運河・青緑の水面","#395458",.42f,.81f));
        e.stone.Upload(owner.Root,lime,owner); e.sheet.Upload(owner.Root,zinc,owner);
        e.timber.Upload(owner.Root,sash,owner); e.window.Upload(owner.Root,home,owner);
        e.road.Upload(owner.Root,asphalt,owner); e.roof.Upload(owner.Root,distant,owner);
        e.canal.Upload(owner.Root,water,owner);
        bathStone=BathFinish("橋と上がり框の洗出し","Terrazzo","#C2B8A5",.10f,.48f);
        e.terrazzo.Upload(owner.Root,bathStone,owner);
        BuildStreetFixtures(water,zinc);
        Text("電器修理",new Vector3(26.75f,3.26f,-14.085f),.34f,cream,180f);
        Text("仕立",new Vector3(-19.79f,2.22f,-7.01f),.21f,cream,0);
        Text("理髪",new Vector3(13.60f,2.22f,-7.04f),.21f,cream,0);
        var lamp=LightAt("仕立屋の軒先",new Vector3(-17.38f,2.37f,-7.48f),new Color(1,.78f,.51f),1.65f,7.2f);
        lamp.renderMode=LightRenderMode.ForceVertex;
    }
}

