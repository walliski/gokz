/*
	Bhop Tracking
	
	Track player's jump inputs and whether or not they hit perfs
	for a number of their recent bunnyhops.
*/



// =========================  PUBLIC  ========================= //

// Generate 'scroll pattern' report
char[] GenerateBhopPatternReport(int client, int sampleSize = BHOP_SAMPLES, bool colours = true)
{
	char report[512];
	int maxIndex = IntMin(gI_BhopCount[client], sampleSize);
	bool[] perfs = new bool[sampleSize];
	GOKZ_AM_GetHitPerf(client, perfs, sampleSize);
	int[] jumpInputs = new int[sampleSize];
	GOKZ_AM_GetJumpInputs(client, jumpInputs, sampleSize);
	
	for (int i = 0; i < maxIndex; i++)
	{
		if (colours)
		{
			Format(report, sizeof(report), "%s %s%d", 
				report, 
				perfs[i] ? "{green}" : "{default}", 
				jumpInputs[i]);
		}
		else
		{
			Format(report, sizeof(report), "%s %d%s", 
				report, 
				jumpInputs[i], 
				perfs[i] ? "*" : "");
		}
	}
	
	return report;
}



// =========================  LISTENERS  ========================= //

void OnClientPutInServer_BhopTracking(int client)
{
	ResetBhopStats(client);
}

void OnPlayerRunCmd_BhopTracking(int client, int buttons, int cmdnum)
{
	if (!IsPlayerAlive(client) || IsFakeClient(client))
	{
		return;
	}
	
	// If bhop was last tick, then record the stats
	if (HitBhop(client, cmdnum))
	{
		RecordBhopStats(client, Movement_GetHitPerf(client), CountJumpInputs(client));
		CheckForBhopMacro(client);
	}
	
	// Records buttons every tick (after checking if b-hop occurred)
	RecordButtons(client, buttons);
}



// =========================  PRIVATE  ========================= //

static void CheckForBhopMacro(int client)
{
	// Make sure there are enough samples
	if (gI_BhopCount[client] < 20)
	{
		return;
	}
	
	int perfCount = GOKZ_AM_GetPerfCount(client, 20);
	float averageJumpInputs = GOKZ_AM_GetAverageJumpInputs(client, 20);
	
	// Check #1
	if (perfCount >= 17)
	{
		char details[128];
		FormatEx(details, sizeof(details), 
			"High perf ratio - Perfs: %d/20, Pattern: %s", 
			perfCount, 
			GenerateBhopPatternReport(client, 20, false));
		Call_OnPlayerSuspected(client, AMReason_BhopMacro, details);
		return;
	}
	
	// Check #2	
	if (perfCount >= 10 && CheckForRepeatingJumpInputsCount(client, 0.85, 20) >= 2)
	{
		char details[128];
		FormatEx(details, sizeof(details), 
			"Repeating pattern - Perfs: %d/20, Pattern: %s", 
			perfCount, 
			GenerateBhopPatternReport(client, 20, false));
		Call_OnPlayerSuspected(client, AMReason_BhopMacro, details);
		return;
	}
	
	// Check #3
	if (perfCount >= 15 && averageJumpInputs <= 2)
	{
		char details[128];
		FormatEx(details, sizeof(details), 
			"1's or 2's pattern - Perfs: %d/20, Pattern: %s", 
			perfCount, 
			GenerateBhopPatternReport(client, 20, false));
		Call_OnPlayerSuspected(client, AMReason_BhopMacro, details);
		return;
	}
}

/**
 * Returns -1, or the repeating input count if there if there is 
 * an input count that repeats for more than the provided ratio.
 *
 * @param client		Client index.
 * @param ratio			Minimum ratio to be considered 'repeating'.
 * @param sampleSize	Maximum recent bhop samples to include in calculation.
 * @return				The repeating input, or else -1.
 */
static int CheckForRepeatingJumpInputsCount(int client, float ratio = 0.5, int sampleSize = BHOP_SAMPLES)
{
	int maxIndex = IntMin(gI_BhopCount[client], sampleSize);
	int[] jumpInputs = new int[sampleSize];
	GOKZ_AM_GetJumpInputs(client, jumpInputs, sampleSize);
	int maxJumpInputs = RoundToCeil(BUTTON_SAMPLES / 2.0);
	int[] jumpInputsFrequency = new int[maxJumpInputs];
	
	// Count up all the in jump patterns
	for (int i = 0; i < maxIndex; i++)
	{
		jumpInputsFrequency[jumpInputs[i]]++;
	}
	
	// Returns i if more than the given ratio of the sample size has the same jump input count
	int threshold = RoundToCeil(float(sampleSize) * ratio);
	for (int i = 1; i < maxJumpInputs; i++)
	{
		if (jumpInputsFrequency[i] >= threshold)
		{
			return i;
		}
	}
	
	return -1; // -1 if no repeating jump input found
}

// Reset the tracked bhop stats of the client
static void ResetBhopStats(int client)
{
	gI_ButtonCount[client] = 0;
	gI_ButtonsIndex[client] = 0;
	gI_BhopCount[client] = 0;
	gI_BhopIndex[client] = 0;
}

// Returns true if ther was a jump last tick and was within a number of ticks after landing
static bool HitBhop(int client, int cmdnum)
{
	return Movement_GetJumped(client)
	 && Movement_GetTakeoffCmdNum(client) == cmdnum - 1
	 && Movement_GetTakeoffCmdNum(client) - Movement_GetLandingCmdNum(client) <= BHOP_GROUND_TICKS;
}

// Records current button inputs
static int RecordButtons(int client, int buttons)
{
	gI_ButtonsIndex[client] = NextIndex(gI_ButtonsIndex[client], BUTTON_SAMPLES);
	gI_Buttons[client][gI_ButtonsIndex[client]] = buttons;
	gI_ButtonCount[client]++;
}

// Records stats of the bhop
static void RecordBhopStats(int client, bool hitPerf, int jumpInputs)
{
	gI_BhopIndex[client] = NextIndex(gI_BhopIndex[client], BHOP_SAMPLES);
	gB_BhopHitPerf[client][gI_BhopIndex[client]] = hitPerf;
	gI_BhopJumpInputs[client][gI_BhopIndex[client]] = jumpInputs;
	gI_BhopCount[client]++;
}

// Counts the number of times buttons went from !IN_JUMP to IN_JUMP
static int CountJumpInputs(int client, int sampleSize = BUTTON_SAMPLES)
{
	int[] recentButtons = new int[sampleSize];
	SortByRecent(gI_Buttons[client], BUTTON_SAMPLES, recentButtons, sampleSize, gI_ButtonsIndex[client]);
	int maxIndex = IntMin(gI_ButtonCount[client], sampleSize);
	int jumps = 0;
	
	for (int i = 0; i < maxIndex - 1; i++)
	{
		// If buttons went from !IN_JUMP to IN_JUMP
		if (!(recentButtons[i + 1] & IN_JUMP) && recentButtons[i] & IN_JUMP)
		{
			jumps++;
		}
	}
	return jumps;
} 