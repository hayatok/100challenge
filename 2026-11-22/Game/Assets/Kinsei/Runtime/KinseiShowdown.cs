using UnityEngine;

public sealed partial class KinseiSession
{
    enum StageBeat { Approach, Cue, Swing, Opening, Settled }

    const string StageChallenge = "舞台の勝負を受ける";
    const float StageFloor = .48f;
    const float StageCueTime = 1.05f;
    const float StageSwingTime = .34f;
    const float StageOpeningTime = 1.5f;
    const float StageMarkRadius = .83f;
    const float StageBodySpacing = .92f;
    static readonly Vector3 StageSteps = new(-4.9f, 0, 1.36f);
    static readonly Vector3 StageWing = new(-1.37f, 0, 2.37f);
    static readonly Vector3 StageCentre = new(-5, StageFloor, 3.56f);
    static readonly Color StageAmber = new(1f, .60f, .24f);
    static readonly Color StageWhite = new(1f, .92f, .75f);
    static readonly Color StageRest = new(.43f,.47f,.56f);

    Person stageWitness;
    bool stageWitnessAnnounced, stageAnswered;
    float stageBeatEnds;
    StageBeat stageBeat;
    Vector3 stageMark;
    Light stageLamp;
    LineRenderer stageRing;
    Material stageRingMaterial;

    bool StageActive => phase == Phase.Showdown;
    bool CanOrderStageWitness => !finale &&
        (phase == Phase.Arrival || phase == Phase.Floor || (phase == Phase.Choice && escapeTime > 0)) && !boss.retired;
    bool StageWitnessReady => CanOrderStageWitness && stageWitness != null && stageWitness.hp > 0 &&
        Vector3.Distance(stageWitness.Position, StageWing) <= .48f;

    string StageInteraction()
    {
        if (!StageWitnessReady || player.hp <= 0 || Vector3.Distance(player.Position, StageSteps) > 1.23f)
            return "";
        return StageChallenge;
    }

    void OrderStageWitness(Person person)
    {
        if (!CanOrderStageWitness) { Say("今は舞台の立会人を出せない"); return; }
        if (stageWitness == person)
        {
            ClearStageWitness();
            Say(person.name + "が立会を取り消し、真壁に合流する");
            sound.Cue("dial");
            Mark("stage-witness-cancel");
            return;
        }
        if (walkways.Ready && !walkways.GetPath(person.Position, StageWing, searchPath))
        {
            Say("舞台袖への通路がつながっていない");
            return;
        }
        ClearStageWitness();
        if (person == crew[0] && person.duty == Duty.Attend)
        {
            held = false;
            talkProgress = 0;
        }
        person.duty = Duty.StageWitness;
        person.destination = StageWing;
        person.path = null;
        stageWitness = person;
        Say(person.name + "が立会人として舞台袖へ向かう");
        sound.Cue("dial");
        Mark("order-" + chosen + "-StageWitness");
    }

    void ClearStageWitness()
    {
        if (stageWitness != null && stageWitness.duty == Duty.StageWitness)
        {
            stageWitness.duty = Duty.Follow;
            stageWitness.path = null;
        }
        stageWitness = null;
        stageWitnessAnnounced = false;
        if (stageLamp != null) stageLamp.enabled = false;
        if (stageRing != null) stageRing.enabled = false;
    }

    void UpdateStageWitness(float dt)
    {
        if (stageWitness == null) return;
        if (!CanOrderStageWitness || stageWitness.hp <= 0)
        {
            bool down = stageWitness.hp <= 0;
            ClearStageWitness();
            if (down) { Say("立会人が動けない。指揮から交代できる"); Mark("stage-witness-down"); }
            return;
        }
        if (!StageWitnessReady)
        {
            MovePerson(stageWitness, StageWing, 3.2f, dt);
            return;
        }
        Face(stageWitness, StageCentre);
        Motion(stageWitness, "idle");
        if (stageWitnessAnnounced) return;
        stageWitnessAnnounced = true;
        ShowStageLight(StageAmber, .65f, false);
        Say(stageWitness.name + "「舞台袖に着いたで。受けるなら階段の前へ」", 4f);
        sound.Cue("dial");
        Mark("stage-witness-ready");
    }

    void BeginStageShowdown()
    {
        if (StageInteraction() != StageChallenge) return;
        Change(Phase.Showdown);
        MovePlayerToStage(new Vector3(-5.86f, StageFloor, 3.08f));
        boss.root.position = new Vector3(-4.32f, StageFloor, 4.01f);
        boss.hp = bossHp = boss.maxHp;
        int apronIndex = 0;
        foreach (var person in everyone)
        {
            person.watching = null;
            person.flinchUntil = 0;
            if (person == player || person == boss || person.retired) continue;
            if (person.hp <= 0 && person != brother) Motion(person, "fall");
            else if (person == elder) Motion(person, "sit");
            else Motion(person, person == brother && person.hp <= 0 ? "surrender" : "idle");
            var at = person.Position;
            if (at.y > .36f && at.y < .68f && at.x > -7.9f && at.x < -2.1f && at.z > 2.6f && at.z < 4.2f)
            {
                // Clear the front boards for the two participants.
                person.root.position = new Vector3(-7.05f + (apronIndex % 5) * .96f, 0, 1.25f - (apronIndex / 5) * .73f);
                apronIndex++;
            }
            if (person.Position.y < 1f) Face(person, StageCentre);
        }
        Face(player, boss.Position);
        Face(boss, player.Position);
        Vector3 direction = boss.Position - player.Position;
        angle = Mathf.Atan2(direction.x, direction.z) * Mathf.Rad2Deg;
        tilt = 10;
        snapCamera = true;
        moveBlend = shootDelay = attackUntil = hitFlash = lastHit = 0;
        Motion(player, "guard");
        Motion(boss, "guard");
        StartStageBeat(StageBeat.Approach, 2.1f, StageRest, false);
        Say(stageWitness.name + "「立ち会うで。皆、舞台には手ぇ出さんといて」", 3.2f);
        sound.Cue("choice");
    }

    static Vector3 StageBounds(Vector3 position)
    {
        return new Vector3(Mathf.Clamp(position.x, -7.24f, -2.76f), StageFloor,
            Mathf.Clamp(position.z, 3f, 4.11f));
    }

    static Vector3 StageStep(Vector3 from, Vector3 proposed, Vector3 opponent)
    {
        from = StageBounds(from);
        proposed = StageBounds(proposed);
        Vector3 outward = from - StageBounds(opponent);
        float distance = outward.magnitude;
        if (distance < .001f) return from;
        outward /= distance;
        // Keep the lateral part of a step so the two men can pass at arm's length.
        float remaining = distance + Vector3.Dot(proposed - from, outward);
        if (remaining >= StageBodySpacing) return proposed;
        Vector3 slide = StageBounds(proposed + outward * (StageBodySpacing - remaining));
        return Flat(slide, opponent) >= StageBodySpacing - .0001f ? slide : from;
    }

    void MovePlayerToStage(Vector3 position)
    {
        if (motor != null) motor.enabled = false;
        player.root.position = position;
        if (motor != null) motor.enabled = true;
        fallVelocity = 0;
    }

    void SimulateStage(float dt)
    {
        if (stageBeat == StageBeat.Settled)
        {
            if (clock < stageBeatEnds) return;
            if (player.hp <= 0)
                End("loss", "舞台を降りた夜", "舞台灯が落ちた。真壁は仲間に支えられて金星を出た。今夜の興行は兄貴分の手に残る。");
            else
                End("showdown", "舞台でついた決着", "立会人が幕を下ろした。舞台で勝負を見届けた座長は、次の興行を真壁に任せた。");
            return;
        }

        if (player.hp <= 0 || boss.hp <= 0)
        {
            Act(player.hp <= 0 ? player : boss, "fall");
            StartStageBeat(StageBeat.Settled, .75f, StageRest, false);
            return;
        }
        Vector3 grounded = StageBounds(player.Position);
        if (Mathf.Abs(player.Position.y - StageFloor) > .18f || Flat(grounded, player.Position) > .03f)
            MovePlayerToStage(grounded);
        boss.root.position = StageBounds(boss.Position);

        switch (stageBeat)
        {
            case StageBeat.Approach:
                Face(boss, player.Position);
                Vector3 delta = player.Position - boss.Position;
                delta.y = 0;
                if (delta.magnitude > 1.62f)
                {
                    boss.root.position = StageStep(boss.Position, Vector3.MoveTowards(boss.Position,
                        StageBounds(player.Position - delta.normalized * 1.58f), dt * 2.5f), player.Position);
                    Motion(boss, "walk", 2.5f);
                }
                else if (clock >= stageBeatEnds)
                {
                    stageMark = StageBounds(player.Position);
                    Motion(boss, "showdown-cue");
                    StartStageBeat(StageBeat.Cue, StageCueTime, StageAmber, true);
                    sound.Cue("dial");
                }
                else Motion(boss, "guard");
                break;
            case StageBeat.Cue:
                if (clock < stageBeatEnds) break;
                Act(boss, "punch");
                StartStageBeat(StageBeat.Swing, StageSwingTime, StageAmber, true);
                break;
            case StageBeat.Swing:
                boss.root.position = StageStep(boss.Position,
                    Vector3.MoveTowards(boss.Position, stageMark, dt * 2.65f), player.Position);
                if (clock < stageBeatEnds) break;
                if (Flat(player.Position, stageMark) <= StageMarkRadius)
                {
                    player.hp = Mathf.Max(0, player.hp - 24);
                    hitFlash = clock + .17f;
                    player.flinchUntil = clock + .23f;
                    sound.Cue("strike");
                    Mark("stage-hit");
                }
                stageAnswered = false;
                Motion(boss, "showdown-open");
                stageMark=boss.Position;
                StartStageBeat(StageBeat.Opening, StageOpeningTime, StageWhite, true);
                break;
            case StageBeat.Opening:
                if (clock >= stageBeatEnds)
                    StartStageBeat(StageBeat.Approach, .32f, StageRest, false);
                break;
        }
        OfferSupper();
    }

    void StageAttack()
    {
        if (clock < shootDelay || stageBeat == StageBeat.Settled || boss.hp <= 0 || player.hp <= 0) return;
        shootDelay = clock + .38f;
        attackUntil = clock + .36f;
        Act(player, "punch");
        if (stageBeat != StageBeat.Opening || stageAnswered || clock >= stageBeatEnds) return;
        if (Flat(player.Position, boss.Position) > 1.95f || !ClearBetween(player, boss))
        {
            Say("もう一歩近づいてから F", 1.05f);
            return;
        }
        Face(player, boss.Position);
        player.actor.SetAttentionTarget(boss.Position + Vector3.up * 1.56f);
        boss.hp = bossHp = Mathf.Max(0, boss.hp - 34);
        boss.flinchUntil = clock + .23f;
        lastHit = clock + .19f;
        stageAnswered = true;
        ShowStageLight(StageRest,.38f,false);
        sound.Cue("strike");
        Mark("stage-answer-" + Mathf.RoundToInt(bossHp));
    }

    void StartStageBeat(StageBeat beat, float duration, Color tint, bool showRing)
    {
        stageBeat = beat;
        stageBeatEnds = clock + duration;
        ShowStageLight(tint, showRing ? 2.7f : .38f, showRing);
        Mark("stage-" + beat);
    }

    void ShowStageLight(Color tint, float brightness, bool showRing)
    {
        if (stageLamp == null)
        {
            stageLamp = new GameObject("立会の合図灯").AddComponent<Light>();
            stageLamp.transform.SetParent(club.transform, false);
            stageLamp.transform.position = StageCentre + Vector3.up * 2.35f;
            stageLamp.type = LightType.Point;
            stageLamp.range = 5.2f;
            stageLamp.shadows = LightShadows.None;
        }
        stageLamp.color = reducedMotion ? StageRest : tint;
        stageLamp.intensity = reducedMotion ? .85f : brightness;
        stageLamp.enabled = true;
        if (!showRing)
        {
            if (stageRing != null) stageRing.enabled = false;
            return;
        }
        if (stageRing == null)
        {
            stageRing = new GameObject("舞台灯の輪").AddComponent<LineRenderer>();
            stageRing.transform.SetParent(club.transform, false);
            stageRing.transform.rotation = Quaternion.Euler(90, 0, 0);
            stageRing.useWorldSpace = false;
            stageRing.alignment = LineAlignment.TransformZ;
            stageRing.loop = true;
            stageRing.positionCount = 48;
            stageRing.startWidth = stageRing.endWidth = .045f;
            stageRingMaterial = new Material(Resources.Load<Shader>("KinseiGlint"));
            stageRing.sharedMaterial = stageRingMaterial;
        }
        for (int i = 0; i < stageRing.positionCount; i++)
        {
            float azimuth = i * 2f * Mathf.PI / stageRing.positionCount;
            Vector3 point = stageMark + new Vector3(Mathf.Cos(azimuth), 0f, Mathf.Sin(azimuth)) * StageMarkRadius;
            // Keep the light on the stage boards, including near the lip.
            point.x = Mathf.Clamp(point.x, -7.95f, -2.05f);
            point.z = Mathf.Clamp(point.z, 2.66f, 4.23f);
            stageRing.SetPosition(i, stageRing.transform.InverseTransformPoint(point + Vector3.up * .021f));
        }
        stageRing.startColor = stageRing.endColor = tint;
        stageRing.enabled = true;
    }

    void DrawStageStatus()
    {
        if (StageActive)
        {
            bool warning = stageBeat == StageBeat.Cue || stageBeat == StageBeat.Swing;
            var tint = warning ? StageAmber : stageBeat == StageBeat.Opening && !stageAnswered ? StageWhite : gold;
            Rect panel = new Rect(hudW - 356, 86, 334, 78);
            Block(panel, ink);
            Block(new Rect(panel.x, panel.y, 3, panel.height), tint);
            Letter(new Rect(panel.x + 13, 88, 305, 27),
                "舞台の立会　／　兄貴分　" + Mathf.CeilToInt(bossHp), 17, cream);
            Meter(new Rect(panel.x + 13, 117, 308, 3), bossHp, tint);
            string cue = stageBeat switch
            {
                StageBeat.Cue => "合図　舞台灯の輪から離れる",
                StageBeat.Swing => "大振り　輪の外へ",
                StageBeat.Opening => stageAnswered ? "打撃が届いた　次の合図を待つ" : "隙　近づいて F",
                StageBeat.Settled => player.hp <= 0 ? "決着　真壁が倒れた" : "決着　兄貴分が倒れた",
                _ => "構え　次の合図を待つ"
            };
            Letter(new Rect(panel.x + 13, 126, 305, 30), cue, 18, tint, true);
            return;
        }
        if (stageWitness == null || !CanOrderStageWitness || shopView != ShopView.None) return;
        Rect note = new Rect(hudW - 350, phase == Phase.Choice ? 126 : 86, 328, 54);
        Block(note, ink);
        Block(new Rect(note.x, note.y, 3, note.height), StageWitnessReady ? mint : brass);
        Letter(new Rect(note.x + 13, note.y, 300, 26), "舞台の立会　／　" + stageWitness.name, 16, gold);
        Letter(new Rect(note.x + 13, note.y + 23, 300, 27),
            StageWitnessReady ? "立会人到着　舞台の階段前で E" : "立会人が舞台袖へ移動中", 15, cream);
    }
}
