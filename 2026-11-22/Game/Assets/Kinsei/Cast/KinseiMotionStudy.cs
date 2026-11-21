using System;
using UnityEngine;

/// <summary>Retargets measured CMU marker curves onto the Kinsei cast rig.</summary>
public sealed class KinseiMotionStudy
{
    [Serializable] private class Cycle { public float[] values; public float stride; }
    [Serializable] private class Library { public Cycle walk, run; }
    const int Frames = 64, Channels = 17;
    static Library library;
    static bool attempted;
    readonly float[] sample = new float[Channels];
    readonly Vector3[] anchor = new Vector3[2];
    readonly bool[] planted = new bool[2];
    float phase, runWeight, entrance;
    bool moving, available;

    static bool Valid(Cycle cycle) => cycle != null && cycle.stride > 0 &&
        cycle.values != null && cycle.values.Length == Frames * Channels;

    public bool Pose(bool run, float progress, float dt, float turn, Transform pelvis, Transform spine,
        Transform leftArm, Transform rightArm, Transform leftElbow, Transform rightElbow)
    {
        if (!attempted)
        {
            attempted = true;
            var resource = Resources.Load<TextAsset>("KinseiMotion/Cycles");
            if (resource) library = JsonUtility.FromJson<Library>(resource.text);
        }
        available = library != null && Valid(library.walk) && Valid(library.run);
        if (!available) return false;

        float targetWeight = run ? 1 : 0;
        if (!moving) runWeight = targetWeight;
        moving = true;
        runWeight = Mathf.MoveTowards(runWeight, targetWeight, dt * 5);
        entrance = Mathf.MoveTowards(entrance, 1, dt * 6);
        phase = Mathf.Repeat(progress, 1);
        float position = phase * Frames;
        int frame = Mathf.FloorToInt(position);
        int next = ((frame + 1) % Frames) * Channels;
        float fraction = position - frame;
        for (int i = 0; i < Channels; i++)
        {
            int current = frame * Channels + i;
            float walk = Mathf.Lerp(library.walk.values[current], library.walk.values[next+i], fraction);
            float jog = Mathf.Lerp(library.run.values[current], library.run.values[next+i], fraction);
            sample[i] = Mathf.Lerp(walk, jog, runWeight);
        }
        pelvis.localPosition += new Vector3(sample[0], sample[1] - Mathf.Lerp(.068f,.094f,runWeight), 0);
        pelvis.localRotation = Quaternion.Euler(0, sample[2], sample[3]);
        spine.localRotation = Quaternion.Euler(sample[4], sample[5]+turn*.5f, sample[6]);
        leftArm.localRotation = Quaternion.Euler(sample[7]-sample[4], turn*.2f, -5);
        rightArm.localRotation = Quaternion.Euler(sample[12]-sample[4], turn*.2f, 5);
        leftElbow.localRotation = Quaternion.Euler(sample[8],0,0);
        rightElbow.localRotation = Quaternion.Euler(sample[13],0,0);
        return true;
    }

    public delegate void LimbSolver(Transform hip, Transform knee, Transform ankle,
        Vector3 target, Vector3 pole, float weight);

    public void Feet(Transform root, float stride, float turn, Transform leftHip, Transform leftKnee,
        Transform leftAnkle, Transform rightHip, Transform rightKnee, Transform rightAnkle, LimbSolver solve)
    {
        if (!available) return;
        Foot(root,stride,turn,0,leftHip,leftKnee,leftAnkle,solve);
        Foot(root,stride,turn,1,rightHip,rightKnee,rightAnkle,solve);
    }

    void Foot(Transform root, float stride, float turn, int index, Transform hip, Transform knee,
        Transform ankle, LimbSolver solve)
    {
        int channel = index == 0 ? 9 : 14;
        int side = index == 0 ? -1 : 1;
        float step = Mathf.Repeat(phase + index*.5f,1);
        float pitch = Mathf.Clamp(sample[channel+2],-28,65);
        Quaternion rotation = Quaternion.Euler(pitch, side*5+turn*.22f,0);
        // Lowest point on the rig's ellipsoidal sole, in the ankle's rotated parent frame.
        float radians = pitch*Mathf.Deg2Rad;
        float sin = Mathf.Sin(radians), cos = Mathf.Cos(radians);
        float radius = Mathf.Sqrt(.017f*.017f*cos*cos + .124f*.124f*sin*sin);
        Vector3 sole = rotation * new Vector3(0,-.052f-.017f*.017f*cos/radius,
            .056f+.124f*.124f*sin/radius);
        float floorHeight = -sole.y;
        Vector3 target = root.TransformPoint(new Vector3(side*(.091f+Mathf.Abs(turn)*.0009f),
            Mathf.Max(floorHeight,.069f+sample[channel+1]), sample[channel]*stride+.013f));
        float start = Mathf.Lerp(.115f,.12f,runWeight), end = Mathf.Lerp(.45f,.26f,runWeight);
        bool stance = step >= start && step < end;
        if (stance)
        {
            Vector3 contact = target + root.TransformVector(sole);
            if (!planted[index] || (contact-anchor[index]).sqrMagnitude > .25f)
            {
                anchor[index] = contact;
                anchor[index].y = root.position.y;
            }
            float release = Mathf.SmoothStep(0,1,(end-step)/.045f);
            target = Vector3.Lerp(target,anchor[index]-root.TransformVector(sole),release);
        }
        planted[index] = stance;
        solve(hip,knee,ankle,target,root.forward,entrance);
        ankle.rotation = Quaternion.Slerp(ankle.rotation,root.rotation*rotation,entrance);
    }

    public void Reset()
    {
        moving = false;
        entrance = 0;
        planted[0] = planted[1] = false;
    }
}
