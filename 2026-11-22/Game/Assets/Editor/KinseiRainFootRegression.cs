using System;
using System.Reflection;
using UnityEngine;

// Batch entry point. Uses the runtime contact detector, its authored mesh and real metre-scale transforms.
public static class KinseiRainFootRegression
{
    const BindingFlags Private=BindingFlags.Instance|BindingFlags.NonPublic;
    static FieldInfo Field(Type type,string name)=>type.GetField(name,Private);

    public static void Run()
    {
        var root=new GameObject("Rain foot regression");
        root.SetActive(false);
        var rain=root.AddComponent<KinseiRainStreet>();
        try {
            typeof(KinseiRainStreet).GetMethod("BuildPatches",Private).Invoke(rain,null);
            var steps=(Vector4[])Field(typeof(KinseiRainStreet),"steps").GetValue(rain);
            var first=Walker(root.transform,-.55f,-10.67f);
            var second=Walker(root.transform,-3.52f,-10.85f);
            var dry=Walker(root.transform,-2.16f,-10.71f);
            rain.Track(1,first,true,0);rain.Track(2,second,true,0);rain.Track(0,dry,true,0);
            Move(rain,1,first,.16f,.12f);Move(rain,2,second,.16f,.12f);Move(rain,0,dry,.16f,.12f);
            Move(rain,2,second,.069f,.23f);Move(rain,1,first,.069f,.24f);
            for(int i=0;i<12;i++){Move(rain,0,dry,.16f,.3f+i*.06f);Move(rain,0,dry,.069f,.33f+i*.06f);}
            Require(Count(steps)==2,"Two crew contacts must survive dry steps from Makabe");
            Require(Mathf.Abs(steps[0].x-second.transform.position.x)<.001f &&
                Mathf.Abs(steps[1].x-first.transform.position.x)<.001f &&
                Mathf.Abs(steps[0].y-(second.transform.position.z+.056f))<.001f,
                "Ripples must begin at the individual sole support points");
            Move(rain,1,first,.16f,1.3f);
            first.transform.Rotate(0,60,0);
            first.StreetShoe(true).localPosition=Vector3.up*.069f;
            rain.Track(1,first,true,1.4f);
            Require(Count(steps)==2,"Turning in place must not plant a ripple");
            first.transform.position+=Vector3.up*.18f;
            Move(rain,1,first,.16f,1.5f);Move(rain,1,first,.069f,1.6f);
            Require(Count(steps)==2,"Raised curb must remain dry");
            Move(rain,2,second,.16f,1.7f);
            rain.ResetContacts();Move(rain,2,second,.069f,.01f);
            Require(Count(steps)==0,"Retry must clear old crests and raised feet");
            var receiver=Walker(root.transform,5.50f,-10.73f);
            rain.Track(0,receiver,true,0);
            Move(rain,0,receiver,.16f,.12f);Move(rain,0,receiver,.069f,.23f);
            Require(Count(steps)==1,"The puddle facing the television must accept a landing");
            Require(Field(typeof(KinseiRainStreet),"heights").GetValue(rain) is byte[] heights && heights.Length==131072,
                "The regression requires the shipped two-channel coverage data");
            var wet=typeof(KinseiRainStreet).GetMethod("InWater",Private);
            var patches=(System.Collections.Generic.List<Bounds>)Field(typeof(KinseiRainStreet),"patches").GetValue(rain);
            Require(patches.Count==10,"Expected all ten street puddles");
            foreach(Bounds patch in patches)
                Require((bool)wet.Invoke(rain,new object[]{patch.center}),"Missing water at "+patch.center);
            // Flat posed sole contacts after two 8mm movements, 56mm in front of each ankle.
            rain.ResetContacts();
            var outsideCore=Walker(root.transform,.185f-.016f,-10.633f-.056f);
            var beside=Walker(root.transform,.285f-.016f,-10.633f-.056f);
            rain.Track(1,outsideCore,true,0);rain.Track(2,beside,true,0);
            Move(rain,1,outsideCore,.16f,.1f);Move(rain,2,beside,.16f,.1f);
            Move(rain,1,outsideCore,.069f,.2f);Move(rain,2,beside,.069f,.2f);
            Require(Count(steps)==1 && Mathf.Abs(steps[0].x-.185f)<.001f,
                "Only the visibly wet outer contact should splash; the dry texels are 10cm away");
            Debug.Log("KINSEI_RAIN_FEET_PASS ten puddles / textured outer boundary / two walkers / dry steps / pivot / curb / retry");
        } finally {
            var field=Field(typeof(KinseiRainStreet),"mesh");
            var mesh=(Mesh)field.GetValue(rain);
            if(mesh)UnityEngine.Object.DestroyImmediate(mesh);
            field.SetValue(rain,null);
            UnityEngine.Object.DestroyImmediate(root);
        }
    }

    static KinseiActor Walker(Transform parent,float x,float z)
    {
        var person=new GameObject("Moving crew member");
        person.transform.SetParent(parent,false);
        person.transform.position=new Vector3(x,0,z);
        var actor=person.AddComponent<KinseiActor>();
        var ankle=new GameObject("Posed left ankle").transform;
        ankle.SetParent(person.transform,false);
        Field(typeof(KinseiActor),"leftShoe").SetValue(actor,ankle);
        return actor;
    }

    static void Move(KinseiRainStreet rain,int seat,KinseiActor actor,float ankleHeight,float time)
    {
        actor.transform.position+=Vector3.right*.008f;
        actor.StreetShoe(true).localPosition=Vector3.up*ankleHeight;
        rain.Track(seat,actor,true,time);
    }

    static int Count(Vector4[] steps)
    {
        int count=0;
        foreach(var step in steps)if(step.w>0)count++;
        return count;
    }

    static void Require(bool condition,string message)
    {
        if(!condition)throw new InvalidOperationException(message);
    }
}
