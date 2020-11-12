package states;

import schema.GameState;
import net.Net;

import flixel.text.FlxBitmapText;
import flixel.graphics.frames.FlxBitmapFont;
import flixel.util.FlxTimer;

import io.colyseus.Client;
import io.colyseus.Room;
import io.colyseus.serializer.schema.Schema;

/**
 * Client interpolation ported from: https://victorzhou.com/blog/build-an-io-game-part-1/#4-client-networking
 */
class TestState extends flixel.FlxState
{
    final render_delay:Int = 100;
    
    var byond:FlxBitmapFont;
    var connecting:FlxBitmapText;
    
    var player:PlayerAvatar;
    var npcs:Map<String, Npc> = [];
    
    var spawnInfo:{ roomName:RoomName, ?x:Float, ?y:Float, ?color:FlxColor };
    
    var first_timestamp:Float = 0;
    var first_server_timestamp:Float = 0;
    
    public function new(roomName = RoomName.Default, playerX:Float = null, playerY:Float = null, playerColor:FlxColor = null)
    {
        super();
        
        spawnInfo = { roomName:roomName, x:playerX, y:playerY, color:playerColor };
    }
    
    override public function create():Void
    {
        super.create();
        
        byond = FlxBitmapFont.fromAngelCode(Fonts.byond__png, Fonts.byond__fnt);
        
        connecting = new FlxBitmapText(byond);
        connecting.text = 'connecting...';
        connecting.scale.set(0.5,0.5);
        connecting.screenCenter();
        
        FlxG.camera.bgColor = spawnInfo.roomName == Default ? 0xFF808080 : 0xFF330066;
        
        add(connecting);
        // new FlxTimer().start(1, timer->init_client());
        init_client();
    }
    
    override public function update(elapsed:Float)
    {
        super.update(elapsed);
        
        if (player != null)
        {
            if (player.timer > PlayerAvatar.SEND_DELAY)
            {
                if (player.x != player.lastSend.x || player.y != player.lastSend.y)
                    Net.send("avatar", { x:player.x, y:player.y });
                player.networkUpdate();
            }
            
            switch(spawnInfo.roomName)
            {
                case Default:
                {
                    if (player.x < 0) player.x = 0;
                    if (player.y < 0) player.y = 0;
                    if (player.y > FlxG.height - player.height) player.y = FlxG.height - player.height;
                    if (player.x > FlxG.width) exitTo(Second);
                }
                case Second:
                {
                    if (player.x + player.width < 0) exitTo(Default);
                    if (player.y < 0) player.y = 0;
                    if (player.x > FlxG.width - player.width) player.x = FlxG.width - player.width;
                    if (player.y > FlxG.height - player.height) player.y = FlxG.height - player.height;
                }
            }
        }
    }
    
    function exitTo(roomName)
    {
        FlxG.switchState(new TestState(roomName, roomName == Default ? FlxG.width - player.width : 0, player.y, player.testColor));
    }
    
    function init_client() {
        
        Net.joinRoom(spawnInfo.roomName,
            // function joinOrCreate(err:String, room:Room<GameState>)
            function(err, room)
            {
                if (err != null)
                {
                    connecting.text = "Error!";
                    trace("JOIN ERROR: " + err);
                    return;
                }
                
                room.state.avatars.onAdd = (avatar, key) ->
                {
                    // trace("avatar added at " + key + " => " + avatar);
                    trace(room.sessionId + ' added: $key=>${(avatar.color:Int).to_color().rgb.to_hex()} @(${avatar.x}, ${avatar.y}');
                    
                    if (key == room.sessionId)
                        trace(room.sessionId + " this is you!");
                    else
                    {
                        trace(room.sessionId + ' this AINT you');
                        if (!npcs.exists(key))
                        {
                            var npc = new Npc(key, avatar.x, avatar.y, avatar.color);
                            npcs[key] = npc;
                            add(npc);
                            avatar.onChange = npc.onChange;
                        }
                    }
                }
                
                room.state.avatars.onRemove = (avatar, key) ->
                {
                    if (npcs.exists(key))
                    {
                        var npc = npcs[key];
                        npcs.remove(key);
                        remove(npc);
                        avatar.onChange = null;
                    }
                }
                
                // room.state.entities.onChange = function onEntityChange(entity, key)
                // {
                //     trace("entity changed at " + key + " => " + entity);
                // }
                
                // room.onStateChange += process_state_change;
                
                connecting.kill();
                
                player = new PlayerAvatar(spawnInfo.x, spawnInfo.y, spawnInfo.color);
                add(player);
                Net.send("avatar", { x:player.x, y:player.y, color:player.testColor });
            }
        );
    }
    
    function process_state_change(state:GameState)
    {
        trace("State change: " + state);
    }
    
    function current_server_time()
    {
        return first_server_timestamp + (Date.now().getTime() - first_timestamp) - render_delay;
    }
}

class Npc extends Avatar
{
    var key:String;
    public function new(key:String, x = 0.0, y = 0.0, color:Int)
    {
        this.key = key;
        
        super(x, y, color);
    }
    
    public function onChange(changes:Array<DataChange>)
    {
        trace('avatar changes[$key] ' 
            + ([for (change in changes) outputChange(change)].join(", "))
        );
        
        for (change in changes)
        {
            switch (change.field)
            {
                case "x": x = change.value;
                case "y": y = change.value;
            }
        }
    }
    
    inline function outputChange(change:DataChange)
    {
        return change.field + ":" + change.previousValue + "->" + change.value;
    }
}

class PlayerAvatar extends Avatar
{
    inline static public var SEND_DELAY = 0.25;
    
    inline static public var ACCEL_SPEED = Avatar.MAX_SPEED / Avatar.ACCEL_TIME;
    
    public var timer = 0.0;
    public var lastSend = FlxPoint.get();
    
    public function new(x:Float = null, y:Float = null, color:FlxColor = null)
    {
        final m = 20;
        final w = FlxG.width - m;
        final h = FlxG.height - m;
        
        if (x == null) x = FlxG.random.float(m, w);
        if (y == null) y = FlxG.random.float(m, h);
        if (color == null) color = FlxColor.fromHSB(FlxG.random.float(0, 360), 1, 1);
        
        super(x, y, color);
        lastSend.set(x, y);
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        color = testColor;
        timer += elapsed;
        
        final pressR = FlxG.keys.pressed.RIGHT;
        final pressL = FlxG.keys.pressed.LEFT;
        final pressU = FlxG.keys.pressed.UP;
        final pressD = FlxG.keys.pressed.DOWN;
        
        acceleration.x = ((pressR ? 1 : 0) - (pressL ? 1 : 0)) * ACCEL_SPEED;
        acceleration.y = ((pressD ? 1 : 0) - (pressU ? 1 : 0)) * ACCEL_SPEED;
    }
    
    public function networkUpdate()
    {
        timer -= SEND_DELAY;
        lastSend.set(x, y);
        color = FlxColor.WHITE;
    }
}

class Avatar extends FlxSprite
{
    inline static public var ACCEL_TIME = 0.2;
    inline static public var MAX_SPEED = 200;
    
    public var testColor = 0x0;
    
    public function new(x = 0.0, y = 0.0, color:Int)
    {
        super(x, y);
        
        makeGraphic(20, 20);
        testColor = this.color = color;
        
        maxVelocity.set(MAX_SPEED, MAX_SPEED);
        drag.set(MAX_SPEED / ACCEL_TIME, MAX_SPEED / ACCEL_TIME);
    }
}
