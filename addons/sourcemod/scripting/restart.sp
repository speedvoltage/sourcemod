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
#define PLUGIN_NAME								"SUBLIME | Server Restart"
#define PLUGIN_AUTHOR							"Peter Brev"
#define PLUGIN_VERSION							SOURCEMOD_VERSION
#define PLUGIN_DESCRIPTION						"Allows Server Restarts"
#define PLUGIN_URL								"https://peterbrev.info"

/*Plugin defines for messages*/
#define PREFIX										"[RESTART]"
#define MESSAGE									"The server is restarting in 10 seconds!"
#define MESSAGE_COLOR							"{lime}"

/******************************
PLUGIN HANDLES
******************************/



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
	
	//Nothing
	
	/***COMMANDS SETUP***/
	
	RegAdminCmd("sm_restart", Command_Restart, ADMFLAG_ROOT, "Allows server restart in-game");
}

/******************************
PUBLIC CALLBACKS
******************************/

public Action Command_Restart(int client, int args)
{
	CPrintToChatAll("%s%s %s", MESSAGE_COLOR, PREFIX, MESSAGE);
	CreateTimer(10.0, Command_ServerRestart);
}

public Action Command_ServerRestart(Handle timer, any data)
{
	ServerCommand("_restart");
}
/**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
*****************************************************************!AND THE DREAM ENDS HERE!********************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************/