state("mupen64-rerecording-v2-reset")
{
	byte Stars : 0x827CA8;
	byte level : 0x81A88A;
	byte music : 0x70F0AE;
	int anim: 0x827C0C;
	int time: 0x81A010;
}

startup
{
    settings.Add("LI", false, "Enable Last Impact start mode");
	settings.Add("DelA", false, "Delete File A on game reset");
	settings.Add("LastSplit", true, "Split on final split when Grand Star or regular star was grabbed");
	
	refreshRate = 30;
}

init
{
	vars.split = 0;
	vars.delay = -1;
	vars.lastSymbol = (char) 0;
	vars.deleteFile = false;
	
	vars.errorCode = 0;
	vars.ResetIGTFixup = 0;
	vars.forceSplit = false;
}

start
{
	vars.split = 0;
	if (settings["LI"])
		return (old.level == 35 && current.level == 16);
	else{
		if(settings["DelA"] && current.level == 1 && old.time > current.time)
			vars.deleteFile = true;
		return (current.level == 1 && old.time > current.time);
	}
}

reset
{
	String splitName = timer.CurrentSplit.Name;
	char lastSymbol = splitName.Last();
	if (settings["LI"]){
		return (old.level == 35 && current.level == 16 && current.Stars == 0);
	}else if (current.level == 1 && old.time > current.time){
		return lastSymbol != 'R';
	}
}

split
{
	if (vars.split == 0){
		String splitName = timer.CurrentSplit.Name;
		char lastSymbol = splitName.Last();
		bool isKeySplit = (splitName.ToLower().IndexOf("key") != -1) || (lastSymbol == '*');
		
		if (0 == 1 && timer.Run.Count - 1 == timer.CurrentSplitIndex && (current.anim == 6409 || current.anim == 6404 || current.anim == 4866 || current.anim == 4871))
		{
			if (settings["LastSplit"])
				return true;
		}
		else if (lastSymbol == ')' && old.Stars < current.Stars)
		{
			print("Star trigger!");
			char[] separators = {'(', ')', '[', ']'};
 
			String splitStarCounts = splitName.Split(separators, StringSplitOptions.RemoveEmptyEntries).Last();
		
			int splitStarCount = -1;
			Int32.TryParse(splitStarCounts, out splitStarCount);
			
			if (splitStarCount == current.Stars && !isKeySplit) //Postpone key split to later
				vars.split = 1;
		} 
		else if (lastSymbol == ']' && old.level != current.level)
		{
			print("Level trigger!");
			char[] separators = {'(', ')', '[', ']'};

			String splitLevelCounts = splitName.Split(separators, StringSplitOptions.RemoveEmptyEntries).Last();
		
			int splitLevelCount = -1;
			Int32.TryParse(splitLevelCounts, out splitLevelCount);
			
			if (splitLevelCount == current.level)
				vars.split = 1;		
		}
		else if (lastSymbol == '!' && old.music != current.music)
		{
			print("Music trigger!");
			if (current.music == 0)
				return true;
		}
		else if (lastSymbol == 'R')
		{
			print("Reset trigger!");
			if (vars.forceSplit) {
				vars.forceSplit = false;
				return true;
			}
		}
		else if (isKeySplit && old.anim != current.anim && current.anim == 4866) //Key grab animation == 4866
		{
			print("Key split trigger!");
			char[] separators = {'(', ')', '[', ']', '*'};

			String splitStarCounts = splitName.Split(separators, StringSplitOptions.RemoveEmptyEntries).Last();
		
			int splitStarCount = -1;
			Int32.TryParse(splitStarCounts, out splitStarCount);
			
			if (splitStarCount == current.Stars)
				vars.split = 5;
		}
	}

	if (vars.split == 1)
	{
		vars.forceSplit = false;
		String splitName = timer.CurrentSplit.Name;
		if (current.level != old.level || (old.anim != current.anim && old.anim == 4866) || (old.anim != current.anim && old.anim == 4867) || (old.anim != current.anim && old.anim == 4871) || (old.anim != current.anim && old.anim == 4866)){
			vars.split = -20;
			return true;
		}
	}
	
	if (vars.split > 1)
		vars.split--;
		
	if (vars.split < 0)
		vars.split++;
}

update
{
	if (!vars.forceSplit)
		vars.forceSplit = current.time < old.time;
	if (vars.deleteFile)
	{
		if (timer.CurrentTime.RealTime.Value.TotalSeconds < 4) {
			vars.split = 0;
			byte[] data = Enumerable.Repeat((byte)0x00, 0x70).ToArray();
			//DeepPointer fileA = new DeepPointer("Project64.exe", 0x4C054, 0x207708); //TODO: this is better solution
			IntPtr ptr;
		
			var module =  modules.FirstOrDefault(m => m.ModuleName.ToLower() == "rsp 1.7.dll");
			ptr = module.BaseAddress + 0x5B3CC;
		
			if (!game.ReadPointer(ptr, false, out ptr) || ptr == IntPtr.Zero)
			{
				vars.errorCode |= 1;
				print("readptr fail");
			}
			ptr += 0x207708;
			if (!game.WriteBytes(ptr, data))
			{ 
				vars.errorCode |= 2;
				print("write fail");
			}
			vars.delay = -1;
		}else{
			if (timer.CurrentTime.RealTime.Value.TotalSeconds < 5)
				vars.deleteFile = false;
		}
	}
}

gameTime
{
		int relaxMilliseconds = 5000;
		int relaxFrames = relaxMilliseconds * 60 / 1000;
	
		try{
			if (timer.CurrentTime.RealTime.Value.TotalMilliseconds > relaxMilliseconds) {
				if (current.time < old.time) //Reset happened 
				{ 
					vars.ResetIGTFixup += old.time;
				}
			}else{
				vars.ResetIGTFixup = 0;
				if (current.time > relaxFrames)
					return TimeSpan.FromMilliseconds(0); 
			}
		}catch(Exception) {
			vars.ResetIGTFixup = 0;
		} 
		return TimeSpan.FromMilliseconds((double)(vars.ResetIGTFixup + current.time) * 1000 / 60.0416);
}
