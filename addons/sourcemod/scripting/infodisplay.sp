/**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
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
#include <geoip>

/******************************
COMPILE OPTIONS
******************************/

#pragma semicolon 1

/******************************
PLUGIN HANDLES
******************************/

/******************************
PLUGIN DEFINES
******************************/

/*Plugin Info*/
#define PLUGIN_NAME								"Sublime | Info Display"
#define PLUGIN_AUTHOR							"Peter Brev"
#define PLUGIN_VERSION							"1.0.0.0"
#define PLUGIN_DESCRIPTION						"Displays the info of players to admins only"
#define PLUGIN_URL								"https://peterbrev.info"

/*Plugin defines for messages*/
#define PREFIX									"[SUBLIME]"
#define COLOR_PREFIX							"{fullred}"
#define COLOR_PLAYER							"{unique}"
#define COLOR_LIME							"{green}"
#define COLOR_AZURE							"{azure}"

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
	/***COMMANDS SETUP***/
	
	//Let us go ahead and first set up a ConVar for the plugin version
	
	CreateConVar("sm_info_version", "1.0.0.0", "Display the current info fetcher version. Used for organization purposes.", FCVAR_NOTIFY|FCVAR_SPONLY);
	
	//Let us register an admin command to fetch a player's IP
	
	RegAdminCmd("sm_info", Command_Info, ADMFLAG_ROOT, "sm_info <#userid|name>");
	
	//Are we done here? Can we move to coding the real thing?
}

/******************************
PUBLIC CALLBACKS
******************************/

public Action Command_Info(int client, int args)
{
	if (!args)
	{
		CReplyToCommand(client, "%s%s %sUsage: %ssm_info <#userid|name>", COLOR_PREFIX, PREFIX, COLOR_AZURE, COLOR_LIME);
		return Plugin_Handled;
	}
	
	char arg1[32];
	
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int Target = FindTarget(client, arg1);

	if (Target == -1) return Plugin_Handled;
	
	char TargetName[MAX_NAME_LENGTH];
	char IP[32];
	char SteamId2[64];
	char SteamId3[64];
	char SteamId64[64];
	char ClientLocation[128];
	
	GetClientName(Target, TargetName, sizeof(TargetName));
	GetClientIP(Target, IP, sizeof(IP));
	GetClientAuthId(Target, AuthId_Steam2, SteamId2, sizeof(SteamId2));
	GetClientAuthId(Target, AuthId_Steam3, SteamId3, sizeof(SteamId3));
	GetClientAuthId(Target, AuthId_SteamID64, SteamId64, sizeof(SteamId64));
	GeoipCountry(IP, ClientLocation, sizeof(ClientLocation));
	
	CReplyToCommand(client, "%s Listing player information:", COLOR_AZURE);	
	CReplyToCommand(client, "%sName: %s%s", COLOR_AZURE, COLOR_LIME, TargetName);
	CReplyToCommand(client, "%sIP: %s%s", COLOR_AZURE, COLOR_LIME, IP);
	CReplyToCommand(client, "%sSteamID2: %s%s", COLOR_AZURE, COLOR_LIME, SteamId2);
	CReplyToCommand(client, "%sSteamID3: %s%s", COLOR_AZURE, COLOR_LIME, SteamId3);
	CReplyToCommand(client, "%sSteamID64: %s%s", COLOR_AZURE, COLOR_LIME, SteamId64);
	CReplyToCommand(client, "%sCountry: %s%s", COLOR_AZURE, COLOR_LIME, ClientLocation);
	
	return Plugin_Handled;
	
}
/**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
*****************************************************************!AND THE DREAM ENDS HERE!********************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************/
