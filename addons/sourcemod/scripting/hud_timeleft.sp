/******************************
COMPILE OPTIONS
******************************/

#pragma semicolon 1
#pragma newdecls required

/******************************
NECESSARY INCLUDES
******************************/

#include <sourcemod>
#include <sdktools>

/******************************
PLUGIN DEFINES
******************************/
/*Setting static strings*/
static const char
	/*Plugin Info*/
	PL_NAME[]		 = "Timeleft HUD",
	PL_AUTHOR[]		 = "Peter Brev",
	PL_DESCRIPTION[] = "Provides timeleft on the HUD",
	PL_VERSION[]	 = "1.0.0";

/******************************
PLUGIN HANDLES
******************************/

Handle g_hTimeLeft;
Handle g_hTimer;

/******************************
PLUGIN INFO
******************************/
public Plugin myinfo =
{
	name		= PL_NAME,
	author		= PL_AUTHOR,
	description = PL_DESCRIPTION,
	version		= PL_VERSION
};

/******************************
INITIATE THE PLUGIN
******************************/
public void OnPluginStart()
{
	/*GAME CHECK*/
	EngineVersion engine = GetEngineVersion();

	if (engine != Engine_HL2DM)
	{
		SetFailState("[HL2MP] This plugin is intended for Half-Life 2: Deathmatch only.");
	}
}

/******************************
PLUGIN FUNCTIONS
******************************/
public void OnMapStart()
{
	g_hTimeLeft = CreateHudSynchronizer();
	g_hTimer	= CreateTimer(1.0, t_UpdateTimeLeft, _, TIMER_REPEAT);
}

public void OnMapEnd()
{
	delete g_hTimeLeft;
	delete g_hTimer;
}

public Action t_UpdateTimeLeft(Handle timer, any data)
{
	static int	time;
	static char timeleft[32];

	GetMapTimeLeft(time);

	if (time > -1)
	{
		if (time > 3600)
		{
			FormatEx(timeleft, sizeof(timeleft), "%ih %02im", time / 3600, (time / 60) % 60);
		}
		else if (time < 60)
		{
			FormatEx(timeleft, sizeof(timeleft), "%02i", time);
		}
		else FormatEx(timeleft, sizeof(timeleft), "%i:%02i", time / 60, time % 60);
	}

	SetHudTextParams(-1.0, 0.01, 1.10, 255, 220, 0, 255, 0, 0.0, 0.0, 0.0);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			ShowSyncHudText(i, g_hTimeLeft, timeleft);
		}
	}
	return Plugin_Continue;
}