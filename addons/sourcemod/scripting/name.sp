/**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
******************************************************************!AND HERE BEGINS A DREAM!*******************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************/

/******************************
INCLUDE ALL THE NECESSARY FILES
******************************/

#include <sourcemod>
#include <sdktools>
#include <morecolors>

/******************************
COMPILE OPTIONS
******************************/

#pragma semicolon 1
#pragma newdecls required

/******************************
PLUGIN DEFINES
******************************/

/*Plugin Info*/
#define PLUGIN_NAME								"Sublime | Set My Name"
#define PLUGIN_AUTHOR							"Peter Brev (Base code provided by Harper)"
#define PLUGIN_VERSION							"1.2.0.0"
#define PLUGIN_DESCRIPTION						"Allows players to use a new name"
#define PLUGIN_URL								"https://peterbrev.info"

/*Plugin defines for messages*/
#define PREFIX_NAME							"[NAME]"
#define PREFIX_COLOR 						"{red}"
#define USAGE_COLOR 							"{azure}"
#define USAGE_COLOR2							"{lime}"
#define USAGE_COLOR3							"{green}"
#define COLOR_PLAYER							"{unique}"

/******************************
PLUGIN HANDLES
******************************/

StringMap g_names;

/******************************
PLUGIN INFO BASED ON PREVIOUS DEFINES
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
	/***PRE-SETUP***/
	
	g_names = CreateTrie();
	
	//We want to hook player_changename in order to block the default message from showing
	
	HookEvent("player_changename", namechange_callback, EventHookMode_Pre);

	/***COMMANDS SETUP***/
	
	//Create a convar for plugin version
	
	CreateConVar("sm_name_version", PLUGIN_VERSION, "Plugin Version", FCVAR_NOTIFY|FCVAR_SPONLY);
	
	//Create the public command
	
	RegConsoleCmd("sm_name", Command_Name, "sm_name <new name> (Leave blank to reset to Steam name)");
	RegConsoleCmd("sm_oname", Command_Oname, "sm_oname <#userid|name> - Find the original Steam name of a player");
	
	//Are we done here? Can we move to coding the real thing?
}

/******************************
PUBLIC CALLBACKS
******************************/

public Action namechange_callback(Event event, const char[] name, bool dontBroadcast)
{
	SetEventBroadcast(event, true);
	return Plugin_Continue;
}

public void OnClientAuthorized(int client)
{
	//Let us grab the SteamID and the name of the connecting players and save them
	
	char id[32], name[MAX_NAME_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, id, sizeof(id));
	GetClientName(client, name, sizeof(name));
	g_names.SetString(id, name);
}

public Action Command_Oname(int client, int args)
{
	//I am going to assume you know your Steam name (else just open your Steam Overlay), so if there is no argument, just provide the command usage
	if (args < 1)
	{
		CReplyToCommand(client, "%s%s %sUsage: %ssm_oname <#userid|name>", USAGE_COLOR2, PREFIX_NAME, USAGE_COLOR, USAGE_COLOR2);
		return Plugin_Handled;
	}
	
	char arg1[64];
	
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int Target = FindTarget(client, arg1, true, false);
	
	if (Target == -1)
	{
		return Plugin_Handled;
	}
	
	char targetname[MAX_TARGET_LENGTH], buffer[MAX_NAME_LENGTH], id[32];
	
	GetClientAuthId(Target, AuthId_Steam2, id, sizeof(id));
	g_names.GetString(id, buffer, sizeof(buffer));
	GetClientName(Target, targetname, sizeof(targetname));
	
	if(strcmp(targetname, buffer))
	{
		CReplyToCommand(client, "%s%s %sSteam name of %s\"%s\" %sis %s\"%s\".", USAGE_COLOR2, PREFIX_NAME, USAGE_COLOR, COLOR_PLAYER, targetname, USAGE_COLOR, COLOR_PLAYER, buffer);
	} else {
		CReplyToCommand(client, "%s%s %sName %s\"%s\" %sis their current Steam name.", USAGE_COLOR2, PREFIX_NAME, USAGE_COLOR, COLOR_PLAYER, targetname, USAGE_COLOR);
	}
	return Plugin_Handled;	
}

public Action Command_Name(int client, int args)
{
	//Let us just make sure to let the server operators know this is an in-game only command
	if (client == 0)
	{
		PrintToServer("%s This command can only be used in-game.", PREFIX_NAME);	
	}

	//With the saved player information, let us prepare the reset name stage
	if(args == 0)
	{
		char id[32], buffer[MAX_NAME_LENGTH], currentname[MAX_NAME_LENGTH];
		
		GetClientAuthId(client, AuthId_Steam2, id, sizeof(id));
		
		g_names.GetString(id, buffer, sizeof(buffer));
		
		GetClientName(client, currentname, sizeof(currentname));
		
		if(strcmp(buffer, currentname, true))
		{
			SetClientName(client, buffer);
			
			CPrintToChatAll("%s%s %s%s %shas reset his name to %s%s %s(Steam Name).", USAGE_COLOR2, PREFIX_NAME, COLOR_PLAYER, currentname, USAGE_COLOR, COLOR_PLAYER, buffer, USAGE_COLOR2);
			LogMessage("Player %s has reset his name to %s", currentname, buffer);
		}
		else
		{
			CPrintToChat(client, "%s%s %sYour name is already set to %s%s.", USAGE_COLOR2, PREFIX_NAME, USAGE_COLOR, COLOR_PLAYER, currentname);
		}
		return Plugin_Handled;
	}

	//Let the player change his name in-game
	if(args > 0)
	{
		char sName[MAX_NAME_LENGTH], currentname[MAX_NAME_LENGTH], steamid[32];
		
		GetClientName(client, currentname, sizeof(currentname));
		
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		
		GetCmdArgString(sName, sizeof(sName));
		
		if(strcmp(sName, currentname))
		{
			SetClientName(client, sName);
			CPrintToChatAll("%s%s %s%s %shas changed his name to %s%s.", USAGE_COLOR2, PREFIX_NAME, COLOR_PLAYER, currentname, USAGE_COLOR, COLOR_PLAYER, sName);
			LogMessage("%s has changed his name to %s", currentname, sName);
		}
		else
		{
			CPrintToChat(client, "%s%s %sYour name is already set to %s%s.", USAGE_COLOR2, PREFIX_NAME, USAGE_COLOR, COLOR_PLAYER, currentname);
		}
	}
	return Plugin_Handled;
}
/**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
*****************************************************************!AND THE DREAM ENDS HERE!********************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************/
