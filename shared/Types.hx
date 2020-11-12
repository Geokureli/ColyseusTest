package;

typedef InputMessage =
{
    time:Float,
    ?mouse:MouseInput,
    ?x:Float,
    ?Y:Float
}

enum abstract MouseInput(String)
{
    var Pressed = 'p';
    var JustPressed = 'jp';
    var JustReleased = 'jr';
}

@:structInit
class GState
{
    public var avatars:Map<String, AvatarState>;
    public var time:Float;
}

@:structInit
class AvatarState
{
    public var id:String;
    public var x:Float;
    public var y:Float;
}

enum abstract PlayerState(Int)
{
    var Idle;
    var Walking;
}
