package;

import flixel.math.FlxRandom;

class Main extends openfl.display.Sprite
{
	public static var random = new FlxRandom();
	
	public function new()
	{
		super();

		// io.newgrounds.NG.createAndCheckSession("50297:xUhNXYLw", Util.uuid());

		// #if debug
		addChild(new flixel.FlxGame(0, 0, states.TestState, 1, 60, 60, true));
		// #else
		// addChild(new flixel.FlxGame(0, 0, states.ClickState, 1, 60, 60, false));
		// #end
		
		FlxG.autoPause = false;
	}
}
