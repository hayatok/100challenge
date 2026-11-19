mergeInto(LibraryManager.library,{
    InspectFloodColumns: function() { return new URLSearchParams(location.search).get('flood-columns')==='1'?1:0; },
    InspectDutyFailure: function(sector,expected,unchanged) {
        var audit=window.evacInspection||(window.evacInspection={buttons:{}});
        audit.duty={sector:sector,expected:expected,unchanged:!!unchanged};
        return location.search.indexOf('duty-failure=1')>=0?1:0;
    },
    InspectMarket: function(leader,pawn,x,z,lift,boarded,finished,meeting,waiting,clock) {
        var audit=window.evacInspection||(window.evacInspection={buttons:{}});
        audit.market={leader:leader,pawn:pawn,x:x,z:z,lift:lift,boarded:boarded,finished:!!finished,
            meeting:!!meeting,waiting:!!waiting,clock:clock};
    },
    InspectClick: function(label) {
        var audit=window.evacInspection||(window.evacInspection={buttons:{}});
        if(!audit.clicks)audit.clicks=[];
        audit.clicks.push(UTF8ToString(label));
        if(audit.clicks.length>12)audit.clicks.shift();
    },
    InspectState: function(phase,mode,ammo,x,z,yaw,fingers) {
        var audit=window.evacInspection||(window.evacInspection={buttons:{}});
        audit.state={phase:UTF8ToString(phase),mode:UTF8ToString(mode),ammo:ammo,x:x,z:z,yaw:yaw,fingers:fingers};
        audit.maxFingers=Math.max(audit.maxFingers||0,fingers);
    },
    InspectButton: function(label,x,y,frame) {
        var audit=window.evacInspection||(window.evacInspection={buttons:{}});
        if(audit.frame!==frame){audit.buttons={};audit.frame=frame;}
        audit.buttons[UTF8ToString(label)]=[x,y];
    }
});
