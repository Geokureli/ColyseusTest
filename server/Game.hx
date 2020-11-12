package;

import schema.Avatar;
import zero.utilities.IntPoint;
import zero.utilities.Vec2;
import Types;

using Util;
using Math;
using zero.extensions.FloatExt;

@:expose
class Game
{
    public function new() {}
    
    public function processMessage(type:String, data:Dynamic, avatar:Dynamic, state:Dynamic)
    {
        if (avatar == null)
            return;
        
        switch (type)
        {
            case "avatar":
                for (field in Reflect.fields(data))
                    Reflect.setField(avatar, field, Reflect.field(data, field));
        }
    }
    
    public function init()
    {
    }

    public function update(dt:Float, state:Dynamic)
    {
    }
}
