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

/******************************
PLUGIN DEFINES
******************************/

/*Plugin Info*/
#define PLUGIN_NAME								"Sublime | Jointeam"
#define PLUGIN_AUTHOR							"Peter Brev"
#define PLUGIN_VERSION							SOURCEMOD_VERSION
#define PLUGIN_DESCRIPTION						"Allows players to join a new team"
#define PLUGIN_URL								"https://peterbrev.info"

/*Plugin defines for messages*/
#define PREFIX_TEAMS								"[TEAMS]"
#define PREFIX_TEAMS_COLOR						"{lime}"
#define TEAMS_COLOR_MESSAGE					"{azure}"

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
	/***REGISTER COMMANDS***/
	
	RegConsoleCmd("sm_spectate", Command_Spectate, "Sends player to spectate");
	RegConsoleCmd("sm_rebels", Command_Rebels, "Sends player to Rebels");
	RegConsoleCmd("sm_combine", Command_Combine, "Sends player to Combine");
	RegConsoleCmd("sm_teams", Command_Jointeam, "Jointeam Menu");
}

public Action Command_Spectate(int client, int args)
{
	char name[MAX_NAME_LENGTH];
	
	GetClientName(client, name, sizeof(name));
	
	ClientCommand(client, "jointeam 1");
	return Plugin_Handled;
}

public Action Command_Rebels(int client, int args)
{
	char name[MAX_NAME_LENGTH];
	
	GetClientName(client, name, sizeof(name));
	
	ClientCommand(client, "jointeam 3");
	return Plugin_Handled;
}

public Action Command_Combine(int client, int args)
{
	char name[MAX_NAME_LENGTH];
	
	GetClientName(client, name, sizeof(name));
	
	ClientCommand(client, "jointeam 2");
	return Plugin_Handled;
}

public Action Command_Jointeam(int client, int args)
{
	CPrintToChat(client, "%s%s %sPress your escape key to choose a team from the menu.", PREFIX_TEAMS, PREFIX_TEAMS_COLOR, TEAMS_COLOR_MESSAGE);
	new Handle:menuhandle = CreateMenu(MenuCallBack);
	SetMenuTitle(menuhandle, "Choose Team");
	AddMenuItem(menuhandle, "spectate", "Spectate");
	AddMenuItem(menuhandle, "jointeam2", "Combine");
	AddMenuItem(menuhandle, "jointeam3", "Rebels");
	SetMenuPagination(menuhandle, MENU_NO_PAGINATION);
	SetMenuExitButton(menuhandle, true);
	DisplayMenu(menuhandle, client, 20);
	return Plugin_Handled;
}
public MenuCallBack(Handle:menuhandle, MenuAction:action, Client, Position)
{
	if(action == MenuAction_Select)
	{
		decl String:Item[20];
		GetMenuItem(menuhandle, Position, Item, sizeof(Item));
		
		if(StrEqual(Item, "spectate"))
		{
			ClientCommand(Client, "spectate");
		} else if (StrEqual(Item, "jointeam2"))
		{
			ClientCommand(Client, "jointeam 2");
		} else if (StrEqual(Item, "jointeam3"))
		{
			ClientCommand(Client, "jointeam 3");
		}
		
	} else if (action == MenuAction_End)
	{
		CloseHandle(menuhandle);
	}
}
/**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
*****************************************************************!AND THE DREAM ENDS HERE!********************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************/