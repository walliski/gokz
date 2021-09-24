
static int jumpTopMode[MAXPLAYERS + 1];
static int jumpTopType[MAXPLAYERS + 1];
static int blockNum[MAXPLAYERS + 1];
static int jumpInfo[MAXPLAYERS + 1][5][3];



void DB_OpenJumpTop(int client, int mode, int jumpType, int blockType)
{
	char query[1024];
	
	Transaction txn = SQL_CreateTransaction();

	FormatEx(query, sizeof(query), sql_jumpstats_gettop, jumpType, mode, blockType, jumpType, mode, blockType, JS_TOP_RECORD_COUNT);
	txn.AddQuery(query);

	DataPack data = new DataPack();
	data.WriteCell(GetClientUserId(client));
	data.WriteCell(mode);
	data.WriteCell(jumpType);
	data.WriteCell(blockType);

	SQL_ExecuteTransaction(gH_DB, txn, DB_TxnSuccess_GetJumpTop, DB_TxnFailure_Generic_DataPack, data, DBPrio_Low);
}

void DB_TxnSuccess_GetJumpTop(Handle db, DataPack data, int numQueries, Handle[] results, any[] queryData)
{
	data.Reset();
	int client = GetClientOfUserId(data.ReadCell());
	int mode = data.ReadCell();
	int type = data.ReadCell();
	int blockType = data.ReadCell();
	delete data;

	if (!IsValidClient(client))
	{
		return;
	}

	jumpTopMode[client] = mode;
	jumpTopType[client] = type;
	blockNum[client] = blockType;

	int rows = SQL_GetRowCount(results[0]);
	if (rows == 0)
	{
		GOKZ_PrintToChat(client, true, "%t", "No Jumpstats Found");
		DisplayJumpTopBlockTypeMenu(client, mode, type);
		return;
	}
	
	char display[128], alias[33], title[65];
	int steamid, block, strafes;
	float distance, sync, pre, max, airtime;

	Menu menu = new Menu(MenuHandler_JumpTopList);
	menu.Pagination = 5;
	
	if (blockType == 0)
	{
		menu.SetTitle("%T", "Jump Top Submenu - Title (Jump)", client, gC_ModeNames[mode], gC_JumpTypes[type]);

		FormatEx(title, sizeof(title), "%s %s %T", gC_ModeNames[mode], gC_JumpTypes[type], "Top", client);
		strcopy(display, sizeof(display), "----------------------------------------------------------------");
		display[strlen(title)] = '\0';
		
		PrintToConsole(client, title);
		PrintToConsole(client, display);
		
		for (int i = 0; i < rows; i++)
		{
			SQL_FetchRow(results[0]);
			steamid = SQL_FetchInt(results[0], JumpstatDB_Top20_SteamID);
			SQL_FetchString(results[0], JumpstatDB_Top20_Alias, alias, sizeof(alias));
			distance = float(SQL_FetchInt(results[0], JumpstatDB_Top20_Distance)) / GOKZ_DB_JS_DISTANCE_PRECISION;
			strafes = SQL_FetchInt(results[0], JumpstatDB_Top20_Strafes);
			sync = float(SQL_FetchInt(results[0], JumpstatDB_Top20_Sync)) / GOKZ_DB_JS_SYNC_PRECISION;
			pre = float(SQL_FetchInt(results[0], JumpstatDB_Top20_Pre)) / GOKZ_DB_JS_PRE_PRECISION;
			max = float(SQL_FetchInt(results[0], JumpstatDB_Top20_Max)) / GOKZ_DB_JS_MAX_PRECISION;
			airtime = float(SQL_FetchInt(results[0], JumpstatDB_Top20_Air)) / GOKZ_DB_JS_AIRTIME_PRECISION;
			
			FormatEx(display, sizeof(display), "#%-2d   %.4f   %s", i + 1, distance, alias);
			menu.AddItem(IntToStringEx(i), display);
			
			PrintToConsole(client, "#%-2d   %.4f   %s <STEAM_1:%d:%d>   [%d %t | %.2f%% %t | %.2f %t | %.2f %t | %.4f %t]", 
				i + 1, distance, alias, steamid & 1, steamid >> 1, strafes, "Strafes", sync, "Sync", pre, "Pre", max, "Max", airtime, "Air");

			jumpInfo[client][i][0] = steamid;
			jumpInfo[client][i][1] = type;
			jumpInfo[client][i][2] = mode;
		}
	}
	else
	{
		menu.SetTitle("%T", "Jump Top Submenu - Title (Block Jump)", client, gC_ModeNames[mode], gC_JumpTypes[type]);

		FormatEx(title, sizeof(title), "%s %T %s %T", gC_ModeNames[mode], "Block", client, gC_JumpTypes[type], "Top", client);
		strcopy(display, sizeof(display), "----------------------------------------------------------------");
		display[strlen(title)] = '\0';
		
		PrintToConsole(client, title);
		PrintToConsole(client, display);
		
		for (int i = 0; i < rows; i++)
		{
			SQL_FetchRow(results[0]);
			steamid = SQL_FetchInt(results[0], JumpstatDB_Top20_SteamID);
			SQL_FetchString(results[0], JumpstatDB_Top20_Alias, alias, sizeof(alias));
			block = SQL_FetchInt(results[0], JumpstatDB_Top20_Block);
			distance = float(SQL_FetchInt(results[0], JumpstatDB_Top20_Distance)) / GOKZ_DB_JS_DISTANCE_PRECISION;
			strafes = SQL_FetchInt(results[0], JumpstatDB_Top20_Strafes);
			sync = float(SQL_FetchInt(results[0], JumpstatDB_Top20_Sync)) / GOKZ_DB_JS_SYNC_PRECISION;
			pre = float(SQL_FetchInt(results[0], JumpstatDB_Top20_Pre)) / GOKZ_DB_JS_PRE_PRECISION;
			max = float(SQL_FetchInt(results[0], JumpstatDB_Top20_Max)) / GOKZ_DB_JS_MAX_PRECISION;
			airtime = float(SQL_FetchInt(results[0], JumpstatDB_Top20_Air)) / GOKZ_DB_JS_AIRTIME_PRECISION;
			
			FormatEx(display, sizeof(display), "#%-2d   %d %T (%.4f)   %s", i + 1, block, "Block", client, distance, alias);
			menu.AddItem(IntToStringEx(i), display);
			
			PrintToConsole(client, "#%-2d   %d %t (%.4f)   %s <STEAM_1:%d:%d>   [%d %t | %.2f%% %t | %.2f %t | %.2f %t | %.4f %t]", 
				i + 1, block, "Block", distance, alias, steamid & 1, steamid >> 1, strafes, "Strafes", sync, "Sync", pre, "Pre", max, "Max", airtime, "Air");
		}
	}
	menu.Display(client, MENU_TIME_FOREVER);
	PrintToConsole(client, "");
}

// =====[ MENUS ]=====

void DisplayJumpTopModeMenu(int client)
{
	Menu menu = new Menu(MenuHandler_JumpTopMode);
	menu.SetTitle("%T", "Jump Top Mode Menu - Title", client);
	GOKZ_MenuAddModeItems(client, menu, false);
	menu.Display(client, MENU_TIME_FOREVER);
}

void DisplayJumpTopTypeMenu(int client, int mode)
{
	jumpTopMode[client] = mode;
	
	Menu menu = new Menu(MenuHandler_JumpTopType);
	menu.SetTitle("%T", "Jump Top Type Menu - Title", client, gC_ModeNames[jumpTopMode[client]]);
	JumpTopTypeMenuAddItems(menu);
	menu.Display(client, MENU_TIME_FOREVER);
}

static void JumpTopTypeMenuAddItems(Menu menu)
{
	char display[32];
	for (int i = 0; i < JUMPTYPE_COUNT - 3; i++)
	{
		FormatEx(display, sizeof(display), "%s", gC_JumpTypes[i]);
		menu.AddItem(IntToStringEx(i), display);
	}
}

void DisplayJumpTopBlockTypeMenu(int client, int mode, int type)
{
	jumpTopMode[client] = mode;
	jumpTopType[client] = type;
	
	Menu menu = new Menu(MenuHandler_JumpTopBlockType);
	menu.SetTitle("%T", "Jump Top Block Type Menu - Title", client, gC_ModeNames[jumpTopMode[client]], gC_JumpTypes[jumpTopType[client]]);
	JumpTopBlockTypeMenuAddItems(client, menu);
	menu.Display(client, MENU_TIME_FOREVER);
}

static void JumpTopBlockTypeMenuAddItems(int client, Menu menu)
{
	char str[64];
	FormatEx(str, sizeof(str), "%T", "Jump Records", client);
	menu.AddItem("jump", str);
	FormatEx(str, sizeof(str), "%T %T", "Block", client, "Jump Records", client);
	menu.AddItem("blockjump", str);
}



// =====[ MENU HANDLERS ]=====

public int MenuHandler_JumpTopMode(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		// param1 = client, param2 = mode
		DisplayJumpTopTypeMenu(param1, param2);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int MenuHandler_JumpTopType(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		// param1 = client, param2 = type
		DisplayJumpTopBlockTypeMenu(param1, jumpTopMode[param1], param2);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_Exit)
	{
		DisplayJumpTopModeMenu(param1);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int MenuHandler_JumpTopBlockType(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		// param1 = client, param2 = block type
		DB_OpenJumpTop(param1, jumpTopMode[param1], jumpTopType[param1], param2);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_Exit)
	{
		DisplayJumpTopTypeMenu(param1, jumpTopMode[param1]);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

public int MenuHandler_JumpTopList(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_Select)
	{
		int botClient = GOKZ_RP_LoadJumpReplay(param1, jumpInfo[param1][param2][0], jumpInfo[param1][param2][1], jumpInfo[param1][param2][2], blockNum[param1]);
		if (botClient != -1)
		{
			// Join spectators and spec the bot
			GOKZ_JoinTeam(param1, CS_TEAM_SPECTATOR);
			SetEntProp(param1, Prop_Send, "m_iObserverMode", 4);
			SetEntPropEnt(param1, Prop_Send, "m_hObserverTarget", botClient);
			
			int clientUserID = GetClientUserId(param1);
			DataPack data = new DataPack();
			data.WriteCell(clientUserID);
			data.WriteCell(GetClientUserId(botClient));

			CreateTimer(0.2, Timer_ResetSpectate, clientUserID);
			CreateTimer(0.3, Timer_SpectateBot, data); // After delay so name is correctly updated in client's HUD
		}
		else
		{
			GOKZ_PlayErrorSound(param1);
		}
	}

	if (action == MenuAction_Cancel && param2 == MenuCancel_Exit)
	{
		DisplayJumpTopBlockTypeMenu(param1, jumpTopMode[param1], jumpTopType[param1]);
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
}

// =====[ UTILITY ]=====

public Action Timer_ResetSpectate(Handle timer, int clientUID)
{
	int client = GetClientOfUserId(clientUID);
	if (IsValidClient(client))
	{
		SetEntProp(client, Prop_Send, "m_iObserverMode", -1);
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", -1);
	}
}
public Action Timer_SpectateBot(Handle timer, DataPack data)
{
	data.Reset();
	int client = GetClientOfUserId(data.ReadCell());
	int botClient = GetClientOfUserId(data.ReadCell());
	delete data;
	
	if (IsValidClient(client) && IsValidClient(botClient))
	{
		GOKZ_JoinTeam(client, CS_TEAM_SPECTATOR);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 4);
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", botClient);
	}
	return Plugin_Continue;
}