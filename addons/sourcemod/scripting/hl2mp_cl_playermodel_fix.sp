/******************************
INCLUDE ALL THE NECESSARY FILES
******************************/

#include <sourcemod>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <updater>

/******************************
COMPILE OPTIONS
******************************/

#pragma semicolon 1
#pragma newdecls required

/******************************
PLUGIN DEFINES
******************************/

/*Plugin Updater*/
#define UPDATE_URL    "https://raw.githubusercontent.com/speedvoltage/sourcemod/master/addons/sourcemod/hl2mp_cl_playermodel_fix.upd"

/*Plugin Info*/
#define PLUGIN_NAME								"HL2MP - Playermodel Fix"
#define PLUGIN_AUTHOR							"Peter Brev"
#define PLUGIN_VERSION							"1.0.0"
#define PLUGIN_DESCRIPTION						"Adjusts players cl_playermodel setting to match their team"
#define PLUGIN_URL								"N/A"

/*Team Colors*/
#define REBELS								"\x07ff3d42"
#define COMBINE								"\x079fcaf2"
#define SPEC								"\x07ff811c"
#define UNASSIGNED							"\x07f7ff7f"

/******************************
PLUGIN STRINGS
******************************/

char ModelsHuman[45][70] =  {
	"models/humans/group01/female_01.mdl", 
	"models/humans/group01/female_02.mdl", 
	"models/humans/group01/female_03.mdl", 
	"models/humans/group01/female_04.mdl", 
	"models/humans/group01/female_06.mdl", 
	"models/humans/group01/female_07.mdl", 
	"models/humans/group01/male_01.mdl", 
	"models/humans/group01/male_02.mdl", 
	"models/humans/group01/male_03.mdl", 
	"models/humans/group01/male_04.mdl", 
	"models/humans/group01/male_05.mdl", 
	"models/humans/group01/male_06.mdl", 
	"models/humans/group01/male_07.mdl", 
	"models/humans/group01/male_08.mdl", 
	"models/humans/group01/male_09.mdl", 
	"models/humans/group02/female_01.mdl", 
	"models/humans/group02/female_02.mdl", 
	"models/humans/group02/female_03.mdl", 
	"models/humans/group02/female_04.mdl", 
	"models/humans/group02/female_06.mdl", 
	"models/humans/group02/female_07.mdl", 
	"models/humans/group02/male_01.mdl", 
	"models/humans/group02/male_02.mdl", 
	"models/humans/group02/male_03.mdl", 
	"models/humans/group02/male_04.mdl", 
	"models/humans/group02/male_05.mdl", 
	"models/humans/group02/male_06.mdl", 
	"models/humans/group02/male_07.mdl", 
	"models/humans/group02/male_08.mdl", 
	"models/humans/group02/male_09.mdl", 
	"models/humans/group03/female_01.mdl", 
	"models/humans/group03female_02.mdl", 
	"models/humans/group03/female_03.mdl", 
	"models/humans/group03/female_04.mdl", 
	"models/humans/group03/female_06.mdl", 
	"models/humans/group03/female_07.mdl", 
	"models/humans/group03/male_01.mdl", 
	"models/humans/group03/male_02.mdl", 
	"models/humans/group03/male_03.mdl", 
	"models/humans/group03/male_04.mdl", 
	"models/humans/group03/male_05.mdl", 
	"models/humans/group03/male_06.mdl", 
	"models/humans/group03/male_07.mdl", 
	"models/humans/group03/male_08.mdl", 
	"models/humans/group03/male_09.mdl"
};

/******************************
PLUGIN BOOLEANS
******************************/

bool g_bPlayerModel[MAXPLAYERS + 1] =  { true, ... };

/******************************
PLUGIN HANDLES
******************************/

Handle changename_playermodelmsg;
Handle g_hTeamHook;
Handle g_hTeam[MAXPLAYERS + 1];

/******************************
PLUGIN INFO
******************************/

public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = PLUGIN_AUTHOR, 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = PLUGIN_URL, 
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
		SetFailState("[HL2MP] This fix is intended for Half-Life 2: Deathmatch only.");
	}
	
	/*UPDATER?*/
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	
	/*PRECACHE MODELS*/
	for (int i; i < sizeof(ModelsHuman); i++)
	{
		PrecacheModel(ModelsHuman[i]);
	}
	
	/*HOOKS*/
	HookEvent("player_team", playerteam_callback, EventHookMode_Pre); // To fix death when names get changed through SM commands
	
	HookUserMessage(GetUserMessageId("TextMsg"), dfltmsg, true); // To get rid of default engine messages
	
	/*CONVARS*/
	changename_playermodelmsg = CreateConVar("sm_name_playermodel_msg", "1", "Shows message that player model was adjusted based on team", FCVAR_SPONLY | FCVAR_ARCHIVE | FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	g_hTeamHook = CreateConVar("sm_playermodel_fix", "1", "Enable/Disable plugin fix", FCVAR_SPONLY | FCVAR_ARCHIVE | FCVAR_DONTRECORD, true, 0.0, true, 1.0);
	
	/*HOOKING CONVARS*/
	HookConVarChange(g_hTeamHook, OnConVarChanged_pModelFix);
	
	if (GetConVarBool(g_hTeamHook))PrintToServer("[HL2MP] Playermodel fix enabled.");
	else PrintToServer("[HL2MP] Playermodel fix disabled.");
	
	/*PUBLIC COMMANDS*/
	RegConsoleCmd("sm_name_show_playermodel_msg", Command_playermdlmsg, "Display message that player model was adjusted when switching teams");
}

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

public Action playerteam_callback(Event event, const char[] name, bool dontBroadcast) // HL2DM: Fixes death when name gets changed through a command
{
	if (GetConVarBool(g_hTeamHook))
	{
		SetEventBroadcast(event, true);
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		int team = GetEventInt(event, "team");
		int silent = GetEventBool(event, "silent");
		int auto = GetEventBool(event, "autoteam");
		
		if (!client || IsFakeClient(client) || !IsClientInGame(client))
			return Plugin_Handled;
		DataPack pack;
		g_hTeam[client] = CreateDataTimer(0.1, changeteamtimer, pack); // Using a timer because team == 0 causes team change message to show on client disconnect
		pack.WriteCell(client);
		pack.WriteCell(team);
		pack.WriteCell(silent);
		pack.WriteCell(auto);
		return Plugin_Handled;
	}
	else return Plugin_Continue;
}

public Action changeteamtimer(Handle timer, DataPack pack)
{
	int client;
	int team;
	int silent;
	int auto;
	
	pack.Reset();
	client = pack.ReadCell();
	team = pack.ReadCell();
	silent = pack.ReadCell();
	auto = pack.ReadCell();
	
	if (team == 3)
	{
		if (!IsClientInGame(client))
			return Plugin_Stop;
		
		ClientCommand(client, "cl_playermodel models/humans/group03/female_04.mdl");
		SetEntityRenderColor(client, 255, 255, 255, 255);
		if (GetConVarBool(changename_playermodelmsg))
		{
			if (g_bPlayerModel[client])
			{
				PrintToChat(client, "Adjusting your cl_playermodel setting to match your team.");
			}
		}
		PrintToChatAll("%s%N \x01has joined team: %sRebels", REBELS, client, REBELS);
		
		LogAction(client, -1, "%N has changed teams (%s). Client's cl_playermodel parameter adjusted to reflect new team.", client, REBELS);
		
		if (silent == 1 || auto == 1)
		{
			return Plugin_Stop;
		}
		return Plugin_Stop;
	}
	
	if (team == 2)
	{
		if (!IsClientInGame(client))
			return Plugin_Stop;
		
		ClientCommand(client, "cl_playermodel models/police.mdl");
		SetEntityRenderColor(client, 255, 255, 255, 255);
		if (GetConVarBool(changename_playermodelmsg))
		{
			if (g_bPlayerModel[client])
			{
				PrintToChat(client, "Adjusting your cl_playermodel setting to match your team.");
			}
		}
		PrintToChatAll("%s%N \x01has joined team: %sCombine", COMBINE, client, COMBINE);
		
		LogAction(client, -1, "%N has changed teams (%s). Client's cl_playermodel parameter adjusted to reflect new team.", client, COMBINE);
		
		if (silent == 1 || auto == 1)
		{
			return Plugin_Stop;
		}
		return Plugin_Stop;
	}
	
	if (team == 1)
	{
		if (!IsClientInGame(client))
			return Plugin_Stop;
		
		PrintToChatAll("%s%N \x01has joined team: %sSpectators", SPEC, client, SPEC);
		
		LogAction(client, -1, "%N has changed teams (%s). Client's cl_playermodel parameter adjusted to reflect new team.", client, SPEC);
		
		if (silent == 1 || auto == 1)
		{
			return Plugin_Stop;
		}
		return Plugin_Stop;
	}
	
	if (team == 0)
	{
		if (!IsClientInGame(client))
			return Plugin_Stop;
		
		PrintToChatAll("%s%N \x01has joined team: %sPlayers", UNASSIGNED, client, UNASSIGNED);
		
		LogAction(client, -1, "%N has changed teams (%s). Client's cl_playermodel parameter adjusted to reflect new team.", client, UNASSIGNED);
		
		if (silent == 1 || auto == 1)
		{
			return Plugin_Stop;
		}
		return Plugin_Stop;
	}
	return Plugin_Stop;
}

public Action Command_playermdlmsg(int client, int args)
{
	if (GetConVarBool(g_hTeamHook))
	{
		if (GetConVarBool(changename_playermodelmsg))
		{
			if (!args || args > 2)
			{
				PrintToChat(client, "Usage: \x04sm_name_show_playermodel_msg <0|1>");
				return Plugin_Handled;
			}
			
			char arg[5];
			
			GetCmdArgString(arg, sizeof(arg));
			
			if (StrEqual(arg, "1"))
			{
				if (g_bPlayerModel[client])
				{
					PrintToChat(client, "Messages are already showing.");
					return Plugin_Handled;
				}
				PrintToChat(client, "Player model adjusted messages now showing.");
				g_bPlayerModel[client] = true;
				return Plugin_Handled;
			}
			
			else if (StrEqual(arg, "0"))
			{
				if (!g_bPlayerModel[client])
				{
					PrintToChat(client, "Messages are already suppressed.");
					return Plugin_Handled;
				}
				PrintToChat(client, "Player model adjusted messages now suppressed.");
				g_bPlayerModel[client] = false;
				return Plugin_Handled;
			}
			
			else
			{
				PrintToChat(client, "Value must be \x040 \x01or \x041\x01.");
				return Plugin_Handled;
			}
		}
		
		else
		{
			PrintToChat(client, "This server has disabled the displaying of adjusted player model messages.");
			return Plugin_Handled;
		}
	}
	
	else
	{
		PrintToChat(client, "This plugin is currently disabled.");
		return Plugin_Handled;
	}
}

public Action dfltmsg(UserMsg msg, Handle hMsg, const int[] iPlayers, int iNumPlayers, bool bReliable, bool bInit)
{
	char sMessage[70];
	
	BfReadString(hMsg, sMessage, sizeof(sMessage), true);
	if (StrContains(sMessage, "more seconds before trying to switch") != -1 || StrContains(sMessage, "Your player model is") != -1 || StrContains(sMessage, "You are on team") != -1)
	{
		return Plugin_Handled; // Get rid of those crap messages
	}
	
	return Plugin_Continue;
}

public void OnConVarChanged_pModelFix(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{
				if (x == 0)
				{
					PrintToServer("[HL2MP] Player will know that their player model is being updated on team change.");
					LogAction(x, -1, "Players know player model is being updated on team change.");
					
				}
				else if (IsClientInGame(x))
				{
					if (GetAdminFlag(GetUserAdmin(x), Admin_Root))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "Player will know that their player model is being updated on team change.");
						PrintToChat(x, xbuffer);
						return;
					}
				}
			}
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("[HL2MP] Player will no longer know that their player model is being updated on team change.");
					LogAction(x, -1, "Players no longer know that their player model is being updated on team change.");
					
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					
					char cbuffer[128];
					Format(cbuffer, sizeof(cbuffer), "Player will no longer know that their player model is being updated on team change.");
					PrintToChat(x, cbuffer);
				}
			}
		}
	}
} 
