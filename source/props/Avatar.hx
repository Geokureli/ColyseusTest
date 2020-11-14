package props;

import flixel.FlxSprite;
import Types;
import states.TestState;

import flixel.FlxG;
import flixel.util.FlxColor;
import flixel.math.FlxPoint;

import io.colyseus.serializer.schema.Schema;

class Npc extends Avatar
{
    var key:String;
    
    public function new(key:String, x = 0.0, y = 0.0, color:Int)
    {
        this.key = key;
        super(x, y, color);
        
        targetPos = FlxPoint.get(this.x, this.y);
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        updateMovement(false, false, false, false, false);
    }
    
    public function onChange(changes:Array<DataChange>)
    {
        trace('avatar changes[$key] ' 
            + ([for (change in changes) outputChange(change)].join(", "))
        );
        
        var oldState = state;
        var newPos = FlxPoint.get(x + frameWidth / 2, y + frameHeight / 2);
        var isMoving = false;
        
        for (change in changes)
        {
            switch (change.field)
            {
                case "x":
                    newPos.x = Std.int(change.value);
                    isMoving = true;
                case "y":
                    newPos.y = Std.int(change.value);
                    isMoving = true;
                case "color":
                    testColor = color = change.value;
                case "state":
                    state = change.value;
            }
        }
        
        if (state != oldState && oldState == Joining)
        {
            x = newPos.x;
            y = newPos.y;
            targetPos = FlxPoint.get(x, y);
        }
        else if (isMoving)
        {
            trace('moving to $newPos');
            setTargetPos(newPos);
        }
        newPos.put();
    }
    
    inline function outputChange(change:DataChange)
    {
        return change.field + ":" + change.previousValue + "->" + change.value;
    }
}

class PlayerAvatar extends Avatar
{
    public var timer = 0.0;
    public var lastSend = FlxPoint.get();
    public var sendDelay = 0.5;
    
    public function new(x, y, color)
    {
        super(x, y, color);
        x -= frameWidth / 2;
        y -= frameHeight / 2;
        lastSend.set(this.x, this.y);
        state = Idle;
        usePaths = false;
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        if (color == FlxColor.WHITE)
        {
            color = testColor;
            setGraphicSize(frameWidth, frameHeight);
        }
        timer += elapsed;
        
        final pressU = FlxG.keys.anyPressed([W, UP]);
        final pressD = FlxG.keys.anyPressed([S, DOWN]);
        final pressL = FlxG.keys.anyPressed([A, LEFT]);
        final pressR = FlxG.keys.anyPressed([D, RIGHT]);
        
        updateMovement(pressU, pressD, pressL, pressR, FlxG.mouse.pressed);
    }
    
    public function networkUpdate()
    {
        timer = 0;
        lastSend.set(Std.int(x), Std.int(y));
        color = FlxColor.WHITE;
        setGraphicSize(frameWidth + 4, frameWidth + 4);
    }
}

class Avatar extends flixel.FlxSprite
{
    inline static public var SIZE = 20;
    inline static public var ACCEL_TIME = 0.2;
    inline static public var MAX_SPEED = 200;
    inline static public var ACCEL_SPEED = MAX_SPEED / ACCEL_TIME;
    
    static var pathTile = new FlxSprite();
    
    public var testColor = 0x0;
    public var state:PlayerState = Joining;
    public var usePaths = true;
    public var drawPath = false;
    
    var targetPos:FlxPoint;
    var movePath:Array<FlxPoint>;
    
    public function new(x = 0.0, y = 0.0, color:Int)
    {
        super(x, y);
        
        makeGraphic(SIZE, SIZE);
        testColor = this.color = color;
        
        maxVelocity.set(MAX_SPEED, MAX_SPEED);
        drag.set(MAX_SPEED / ACCEL_TIME, MAX_SPEED / ACCEL_TIME);
        
        if (pathTile.graphic == null || pathTile.graphic.width == 0)
        {
            pathTile.makeGraphic(32, 32);
            final bitmap = pathTile.graphic.bitmap;
            final rect = bitmap.rect.clone();
            rect.x += 4;
            rect.y += 4;
            rect.width -= rect.x * 2;
            rect.height -= rect.y * 2;
            bitmap.fillRect(rect, 0x0);
            pathTile.offset = pathTile.origin;
        }
    }
    
    override function update(elapsed:Float)
    {
        super.update(elapsed);
        
        if (FlxG.keys.justPressed.L && overlapsPoint(FlxG.mouse.getWorldPosition(FlxPoint.weak())))
        {
            drawPath = !drawPath;
            this.alpha = drawPath ? 0.75 : 1;
        }
    }
    
    function updateMovement(pressU:Bool, pressD:Bool, pressL:Bool, pressR:Bool, pressMouse:Bool)
    {
        if (pressR || pressL || pressU || pressD)
        {
            cancelTargetPos();
        }
        else
        {
            if (pressMouse)
                setTargetPos(FlxG.mouse.getWorldPosition(FlxPoint.weak()).subtract(frameWidth / 2, frameHeight / 2));
            
            var nextPos = targetPos;
            if (movePath != null)
            {
                final map = (cast FlxG.state:TestState).map;
                final index = map.getTileIndexByCoords(FlxPoint.weak(x + frameWidth / 2, y + frameHeight / 2));
                // final index = map.getTileIndexByCoords(FlxPoint.weak(x, y));
                
                while(movePath.length > 1 && map.getTileIndexByCoords(movePath[0]) == index)
                    movePath.shift();//.put();
                
                nextPos = FlxPoint.weak().copyFrom(movePath[0]).subtract(frameWidth / 2, frameHeight / 2);
            }
            
            if (nextPos != null)
            {
                final vx = Math.abs(velocity.x);
                final vy = Math.abs(velocity.y);
                final slideX = Math.max(1, (vx / 2) * (vx / drag.x));
                final slideY = Math.max(1, (vy / 2) * (vy / drag.y));
                
                pressR = x - nextPos.x < -slideX;
                pressL = x - nextPos.x >  slideX;
                pressD = y - nextPos.y < -slideY;
                pressU = y - nextPos.y >  slideY;
                nextPos.putWeak();
            }
        }
        
        acceleration.x = ((pressR ? 1 : 0) - (pressL ? 1 : 0)) * ACCEL_SPEED;
        acceleration.y = ((pressD ? 1 : 0) - (pressU ? 1 : 0)) * ACCEL_SPEED;
    }
    
    override function draw()
    {
        if (drawPath)
        {
            if (movePath != null)
            {
                final len = movePath.length;
                for (i=>pos in movePath)
                {
                    pathTile.x = pos.x;
                    pathTile.y = pos.y;
                    pathTile.alpha = (len - i) / len;
                    pathTile.draw();
                }
            }
            else if (targetPos != null)
            {
                pathTile.x = targetPos.x;
                pathTile.y = targetPos.y;
                pathTile.alpha = 1;
                pathTile.draw();
            }
        }
        super.draw();
    }
    
    public function setTargetPos(newPos:FlxPoint)
    {
        if (usePaths)
            calcNewPath(newPos);
        else
        {
            if (movePath != null)
            {
                solid = true;
                movePath = null;
            }
            
            if (targetPos == null)
                targetPos = FlxPoint.get();
            targetPos.copyFrom(newPos);
        }
        
        newPos.putWeak();
    }
    
    function calcNewPath(newPos:FlxPoint)
    {
        final map = (cast FlxG.state:TestState).map;
        final start = FlxPoint.get(x, y);
        final end = FlxPoint.get(newPos.x, newPos.y);
        if (targetPos == null || map.getTileIndexByCoords(end) != map.getTileIndexByCoords(targetPos))
        {
            if (targetPos == null)
                targetPos = FlxPoint.get();
            targetPos.copyFrom(newPos);
            movePath = map.findPath(start, end, false, WIDE);
            solid = movePath == null;
        }
        start.put();
        end.put();
    }
    
    function cancelTargetPos()
    {
        targetPos = null;
        movePath = null;
        solid = true;
    }
}