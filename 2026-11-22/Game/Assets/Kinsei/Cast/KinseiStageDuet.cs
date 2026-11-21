using UnityEngine;

/// <summary>The game passes the playing score's time and actual keytop contact points each frame.</summary>
public sealed class KinseiStageDuet : MonoBehaviour
{
    KinseiActor singer,pianist;
    Transform piano;
    Vector3[] singerRoute,pianistRoute;
    float singerDistance,pianistDistance,singerContact=1,pianoContact=1;
    bool performing=true;

    public static KinseiStageDuet Install(Transform world)
    {
        var existing=world.GetComponentInChildren<KinseiStageDuet>(true);
        if(existing)return existing;
        var instrument=world.Find("Walnut upright piano");
        if(!instrument)return null;
        var group=new GameObject("金星の専属歌手と伴奏者");
        group.transform.SetParent(world,false);
        var duet=group.AddComponent<KinseiStageDuet>();
        duet.piano=instrument;
        var voice=world.TransformPoint(new Vector3(-4.94f,.48f,3.64f));
        var bench=instrument.TransformPoint(new Vector3(.015f,-.02f,-.75f));
        duet.singerRoute=new[]{voice,world.TransformPoint(new Vector3(-5.35f,.48f,4.24f)),
            world.TransformPoint(new Vector3(-5.56f,.48f,5.52f)),world.TransformPoint(new Vector3(-5.69f,.48f,6.32f))};
        // Walk off the end of the bench, clear the piano's bass side, then pass through the curtain.
        duet.pianistRoute=new[]{bench,instrument.TransformPoint(new Vector3(.015f,-.02f,-.54f)),
            instrument.TransformPoint(new Vector3(-.73f,-.02f,-.54f)),
            world.TransformPoint(new Vector3(-4.43f,.48f,4.65f)),world.TransformPoint(new Vector3(-4.50f,.48f,6.32f))};
        duet.singer=duet.Create("『夜の椿』専属歌手","stage-singer",3,voice,world.rotation*Quaternion.Euler(0,180,0));
        duet.pianist=duet.Create("『三人の乾杯』ピアニスト","stage-pianist",5,bench,instrument.rotation);
        duet.pianist.BeginSeated();
        return duet;
    }

    KinseiActor Create(string caption,string role,int variant,Vector3 at,Quaternion facing)
    {
        var person=new GameObject(caption);
        person.transform.SetParent(transform,false);person.transform.SetPositionAndRotation(at,facing);
        var actor=person.AddComponent<KinseiActor>();actor.Init(role,variant);return actor;
    }

    public void SetPerforming(bool value) { performing=value; }

    public void Tick(float dt,float songSeconds,Vector3 leftKeyWorld,Vector3 rightKeyWorld)
    {
        if(!piano || dt<=0)return;
        Move(singer,singerRoute,ref singerDistance,ref singerContact,dt,false);
        Move(pianist,pianistRoute,ref pianistDistance,ref pianoContact,dt,true);
        if(singerContact>0)
            singer.SingAtStand(transform.TransformPoint(new Vector3(-5,1.835f,3.4f)),songSeconds,singerContact);
        if(pianoContact>0)pianist.PlayKeys(leftKeyWorld,rightKeyWorld,songSeconds,pianoContact);
    }

    void Move(KinseiActor actor,Vector3[] route,ref float distance,ref float contact,float dt,bool seated)
    {
        float length=0;
        for(int i=1;i<route.Length;i++)length+=Vector3.Distance(route[i-1],route[i]);
        bool atMark=distance<.001f;
        contact=Mathf.MoveTowards(contact,performing && atMark?1:0,dt*(performing?2.8f:3.6f));
        if(!performing && contact>0 || performing && atMark)
        {
            actor.Pose(seated?"sit":"idle",0);
            actor.transform.rotation=Quaternion.RotateTowards(actor.transform.rotation,seated?piano.rotation:transform.rotation*Quaternion.Euler(0,180,0),dt*290);
            return;
        }
        distance=Mathf.MoveTowards(distance,performing?0:length,dt*(seated?1.19f:1.32f));
        if(!performing && distance>=length)
        {
            actor.gameObject.SetActive(false);return;
        }
        actor.gameObject.SetActive(true);
        float remaining=distance;
        for(int i=1;i<route.Length;i++)
        {
            Vector3 delta=route[i]-route[i-1];float segment=delta.magnitude;
            if(remaining>segment && i<route.Length-1){remaining-=segment;continue;}
            actor.transform.position=route[i-1]+delta*Mathf.Clamp01(remaining/segment);
            Quaternion facing=Quaternion.LookRotation(performing?-delta:delta,transform.up);
            actor.transform.rotation=Quaternion.RotateTowards(actor.transform.rotation,facing,dt*305);
            break;
        }
        actor.Pose("walk",seated?1.19f:1.32f);
    }
}
