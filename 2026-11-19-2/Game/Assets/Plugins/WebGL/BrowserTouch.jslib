mergeInto(LibraryManager.library, {
    ReadFieldTouches: function(buffer, capacity) {
        var canvas = Module.canvas;
        if (!canvas) return 0;
        var contacts = canvas.evacContacts;
        if (!contacts) {
            contacts = canvas.evacContacts = [];
            var update = function(event) {
                var bounds = canvas.getBoundingClientRect();
                if (!bounds.width || !bounds.height) return;
                for (var i = 0; i < event.changedTouches.length; i++) {
                    var touch = event.changedTouches[i], id = touch.identifier;
                    var x = (touch.clientX - bounds.left) / bounds.width;
                    var y = 1 - (touch.clientY - bounds.top) / bounds.height;
                    var contact = contacts.find(function(item) {return item.id === id && !item.end;});
                    if (event.type === 'touchstart') {
                        if (!contact && contacts.length < capacity) {
                            var slot=0;
                            while (contacts.some(function(item){return item.slot===slot;})) slot++;
                            contacts.push({id:id, slot:slot, x:x, y:y, lastX:x, lastY:y, first:true, end:0});
                        }
                    } else if (contact) {
                        contact.x=x; contact.y=y;
                        if (event.type === 'touchend') contact.end=3;
                        if (event.type === 'touchcancel') contact.end=4;
                    }
                }
            };
            ['touchstart','touchmove','touchend','touchcancel'].forEach(function(kind) {
                canvas.addEventListener(kind, update, {passive:true, capture:true});
            });
            window.addEventListener('blur',function() {
                contacts.forEach(function(c) {c.end=4;});
            });
        }
        var count = 0;
        for (var j = 0; j < contacts.length && count < capacity;) {
            var c = contacts[j], offset = (buffer >> 2) + count * 6;
            var x = c.first ? c.lastX : c.x, y = c.first ? c.lastY : c.y;
            var dx = x - c.lastX, dy = y - c.lastY;
            var phase = c.first ? 0 : c.end || ((dx || dy) ? 1 : 2);
            HEAPF32[offset] = c.slot;
            HEAPF32[offset+1] = phase;
            HEAPF32[offset+2] = x; HEAPF32[offset+3] = y;
            HEAPF32[offset+4] = dx; HEAPF32[offset+5] = dy;
            c.first=false; c.lastX=x; c.lastY=y;
            if (phase >= 3) contacts.splice(j,1); else j++;
            count++;
        }
        return count;
    },
    BrowserTouch: function() { return (location.search.indexOf('controls=touch')>=0 || navigator.maxTouchPoints > 0 && matchMedia("(pointer: coarse)").matches) ? 1 : 0; },
    BrowserHasLook: function() {return document.pointerLockElement===Module.canvas ? 1 : 0;},
    BrowserWantsLook: function(wanted) {
        var target=Module.canvas;
        if (!target) return;
        target.dataset.directLook=wanted ? "1" : "0";
        if (!wanted && document.pointerLockElement===target) document.exitPointerLock();
    }
});
