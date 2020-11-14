package states;

import Types;
import net.Net;
import props.Avatar;
import schema.GameState;
import util.AssetPaths;

import flixel.FlxG;
import flixel.graphics.frames.FlxBitmapFont;
import flixel.group.FlxGroup;
import flixel.math.FlxPoint;
import flixel.text.FlxBitmapText;
import flixel.tile.FlxTilemap;
import flixel.util.FlxColor;
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
    inline static var TILE_SIZE = 32;
    
    var byond:FlxBitmapFont;
    var connecting:FlxBitmapText;
    
    public var map:FlxTilemap;
    var player:PlayerAvatar;
    var avatars = new FlxTypedGroup<Avatar>();
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
        
        createTilemap();
        
        if (spawnInfo.x == null && spawnInfo.y == null)
        {
            
            final m = 40;
            final w = FlxG.width - m;
            final h = FlxG.height - m;
            final p = FlxPoint.get();
            var index = 0;
            do
            {
                p.x = FlxG.random.int(1, map.widthInTiles - 1);
                p.y = FlxG.random.int(1, map.heightInTiles - 1);
                index = map.getTile(Std.int(p.x), Std.int(p.y));
            }
            while(map.getTileCollisions(index) != 0);
            spawnInfo.x = (p.x + 0.5) * TILE_SIZE;
            spawnInfo.y = (p.y + 0.5) * TILE_SIZE;
        }
        if (spawnInfo.color == null) spawnInfo.color = FlxColor.fromHSB(FlxG.random.float(0, 36) * 10, 1, 1);
        
        add(avatars);
        
        byond = FlxBitmapFont.fromAngelCode(Fonts.byond__png, Fonts.byond__fnt);
        
        connecting = new FlxBitmapText(byond);
        connecting.text = 'connecting...';
        connecting.scale.set(0.5,0.5);
        connecting.screenCenter();
        
        FlxG.camera.bgColor = spawnInfo.roomName == Default ? 0xFF808080 : 0xFF330066;
        
        add(connecting);
        // new FlxTimer().start(1, timer->init_client());
        initClient();
    }
    
    function createTilemap()
    {
        final rows = Math.floor(FlxG.width  / TILE_SIZE);
        final cols = Math.floor(FlxG.height / TILE_SIZE);
        var tileData = [for (i in 0...rows*cols) 0];
        for(i in 0...cols)
        {
            tileData[i] = 1;
            tileData[rows*cols - i - 1] = 1;
        }
        
        final edge = (spawnInfo.roomName == Default ? 0 : cols - 1);// left or right side
        for(i in 0...rows)
            tileData[cols * i + edge] = 1;
        
        // create random walls
        var oldSeed = FlxG.random.currentSeed;
        FlxG.random.currentSeed = 0;//arbitrary
        for(i in 0...35)
        {
            final index = FlxG.random.int(0, rows*cols);
            tileData[index] = 1;
        }
        
        FlxG.random.currentSeed = oldSeed;
        
        map = new FlxTilemap();
        map.loadMapFromArray(tileData, rows, cols, "assets/images/autotiles.png", 0, 0, AUTO);
        add(map);
    }
    
    override public function update(elapsed:Float)
    {
        super.update(elapsed);
        
        if (player != null)
        {
            
            final moved = Std.int(player.x) != player.lastSend.x || Std.int(player.y) != player.lastSend.y;
            if (!moved)
            {
                player.timer = 0;
            }
            else if (moved && player.timer > player.sendDelay)
            {
                final data = { x:Std.int(player.x), y:Std.int(player.y) };
                trace('sending: (${data.x}, ${data.y})');
                Net.send("avatar", data);
                player.networkUpdate();
            }
            
            
            FlxG.collide(avatars, map);
            
            if (spawnInfo.roomName == Default && player.x + player.width > FlxG.width - 10)
                exitTo(Second);
            
            if (spawnInfo.roomName == Second && player.x < 10)
               exitTo(Default);
            
            if (FlxG.keys.justPressed.P)
            {
                player.usePaths = !player.usePaths;
                if (player.usePaths && !player.drawPath)
                    player.drawPath = true;
            }
            
            if (FlxG.keys.justPressed.ONE  ) player.sendDelay = 1 * 0.25;
            if (FlxG.keys.justPressed.TWO  ) player.sendDelay = 2 * 0.25;
            if (FlxG.keys.justPressed.THREE) player.sendDelay = 3 * 0.25;
            if (FlxG.keys.justPressed.FOUR ) player.sendDelay = 4 * 0.25;
            if (FlxG.keys.justPressed.FIVE ) player.sendDelay = 5 * 0.25;
            if (FlxG.keys.justPressed.SIX  ) player.sendDelay = 6 * 0.25;
            if (FlxG.keys.justPressed.SEVEN) player.sendDelay = 7 * 0.25;
            if (FlxG.keys.justPressed.EIGHT) player.sendDelay = 8 * 0.25;
        }
    }
    
    function exitTo(roomName)
    {
        FlxG.switchState(new TestState(roomName, roomName == Default ? FlxG.width - player.width - 20 : 20, player.y, player.testColor));
    }
    
    function initClient() {
        
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
                    trace(room.sessionId + ' added: $key=>${avatar.color} @(${avatar.x}, ${avatar.y}');
                    
                    if (key == room.sessionId)
                        trace(room.sessionId + " this is you!");
                    else
                    {
                        trace(room.sessionId + ' this AINT you');
                        if (!npcs.exists(key))
                        {
                            var npc = new Npc(key, avatar.x, avatar.y, avatar.color);
                            npcs[key] = npc;
                            avatars.add(npc);
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
                        avatars.remove(npc);
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
                avatars.add(player);
                Net.send("avatar", { x:Std.int(player.x), y:Std.int(player.y), color:player.testColor, state:Idle });
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
