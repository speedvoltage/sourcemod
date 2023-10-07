/** =============================================================================
 * Change Your Name - Main Plugin
 * Core plugin
 *
 * Plugin developed by Peter Brev.
 * SourceMod (C)2004-2008 AlliedModders LLC.  All rights reserved.
 * =============================================================================
 *
 * This program is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License, version 3.0, as published by the
 * Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * As a special exception, AlliedModders LLC gives you permission to link the
 * code of this program (as well as its derivative works) to "Half-Life 2," the
 * "Source Engine," the "SourcePawn JIT," and any Game MODs that run on software
 * by the Valve Corporation.  You must obey the GNU General Public License in
 * all respects for all other code used.  Additionally, AlliedModders LLC grants
 * this exception to all derivative works.  AlliedModders LLC defines further
 * exceptions, found in LICENSE.txt (as of this writing, version JULY-31-2007),
 * or <http://www.sourcemod.net/license.php>.
 *
 * Version: $Id$
 */

/******************************
INCLUDE ALL THE NECESSARY FILES
******************************/

#include <sourcemod>
#include <basecomm>
#include <sdktools>
#undef REQUIRE_PLUGIN
#include <updater>
#include <adminmenu>
#include <sourcebanspp>

TopMenu hAdminMenu = null;

/******************************
COMPILE OPTIONS
******************************/

#pragma semicolon 1
#pragma newdecls required

/******************************
PLUGIN DEFINES
******************************/

/*Plugin Updater*/
#define UPDATE_URL    "https://raw.githubusercontent.com/speedvoltage/sourcemod/master/addons/sourcemod/name_hl2dm.upd"

/*Plugin Info*/
#define PLUGIN_NAME								"Change Your Name"
#define PLUGIN_AUTHOR							"Peter Brev"
#define PLUGIN_VERSION							"1.8.2.1973" /*Build number since 05/12/18*/
#define PLUGIN_DESCRIPTION						"Complete plugin allowing name changes for players + administration tools for admins"
#define PLUGIN_URL								"N/A"

/******************************
PLUGIN BOOLEANS
******************************/

bool g_bMapReload, 
g_bClientAuthorized[MAXPLAYERS + 1] =  { true, ... }, 
g_bForcedName[MAXPLAYERS + 1] =  { true, ... }, 
g_bAdminRenamed[MAXPLAYERS + 1] =  { true, ... };

/******************************
PLUGIN STRINGMAPS
******************************/

StringMap g_names;

/******************************
PLUGIN ARRAYS
******************************/

ArrayList
hBadNames, 
hBannedSteamId;

/******************************
PLUGIN CONVARS
******************************/

ConVar changename_help = null, 
steamname_enable = null, 
changename_enable_global = null, 
changename_enable = null, 
originalname_enable = null, 
changename_steamreset = null, 
changename_bantime = null, 
changename_banreason = null, 
changename_cooldown = null, 
changename_adminrename_cooldown = null;

/******************************
PLUGIN HANDLES
******************************/

Handle g_hTimer[MAXPLAYERS + 1], 
g_hForceLockSteamCheck[MAXPLAYERS + 1], 
g_hNoRename[MAXPLAYERS + 1], 
g_hPluginReload[MAXPLAYERS + 1], 
g_hNameChange[MAXPLAYERS + 1], 
g_hNameReset[MAXPLAYERS + 1];

/******************************
PLUGIN INTEGERS
******************************/

int g_iLastUsed[MAXPLAYERS + 1]; /*Cooldown*/

/*Track the number of times names were changed through this plugin (for statistic purposes "nameadmin plugin stats")*/
int g_iNameChangeTracker, 
g_iNameResetTracker, 
g_iRenameTracker, 
g_iOnameTracker, 
g_iSnameTracker, 
g_iSrnameTracker, 
g_iSteamQueryFail, 
g_iForcedNames;

/*Same, but per player*/
int g_iChangedMyName[MAXPLAYERS + 1], 
g_iResetMyName[MAXPLAYERS + 1], 
g_iWasRenamed[MAXPLAYERS + 1], 
g_iResetToSteam[MAXPLAYERS + 1], 
g_iCheckedOname[MAXPLAYERS + 1], 
g_iCheckedSname[MAXPLAYERS + 1], 
g_iCouldNotQuery[MAXPLAYERS + 1], 
g_iWasForcedNamed[MAXPLAYERS + 1], 
g_iTargetWasSteamChecked[MAXPLAYERS + 1], 
g_iTargetWasOnameChecked[MAXPLAYERS + 1];

int g_iClients[MAXPLAYERS + 1], g_iTimeTotal[MAXPLAYERS + 1];

/******************************
PLUGIN STRINGS
******************************/

/*Name History File*/
char fileName[PLATFORM_MAX_PATH], 
bannedidfile[PLATFORM_MAX_PATH];

char g_sPlayerNameHistory[PLATFORM_MAX_PATH];

/*sm_rename redux*/
char g_targetnewname[MAXPLAYERS + 1][MAX_NAME_LENGTH];

char g_sAllCommands[19][45] =  {
	"sm_name_ban", 
	"sm_name_unban", 
	"sm_name_banid", 
	"sm_name_unbanid", 
	"sm_name_refresh", 
	"sm_name_history", 
	"sm_rename", 
	"sm_rename_random", 
	"sm_rename_force", 
	"sm_rename_unforce", 
	"sm_rename_reset", 
	"nameadmin", 
	"sm_name", 
	"sm_oname", 
	"sm_sname", 
	"sm_srname", 
	"setinfo permaname", 
	"sm_name_help", 
	"sm_name_credits"
};

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
INCLUDE CHANGE YOUR NAME FILES
******************************/

#include "name/name.sp" /*Changing and resetting your name*/
#include "name/oname.sp" /*Fetching a player's name stored in memory when they connected*/
#include "name/sname.sp" /*Fetching a player's Steam name*/
#include "name/srname.sp" /*Fetching a player's Steam name*/
#include "name/namehelp.sp" /*Display public commands*/
#include "name/namecredits.sp" /*Display public commands*/
#include "name/nameban.sp" /*Banning/Unbanning names*/
#include "name/namebanid.sp" /*Banning/Unbanning Steam IDs*/
#include "name/namerefresh.sp" /*Refreshing banned names and IDs on file*/
#include "name/rename.sp" /*Rename players*/
#include "name/renamerandom.sp" /*Random renaming of players names*/
#include "name/nameforce.sp" /*Forcing names*/
#include "name/namehistory.sp" /*Name history*/
#include "name/namereset.sp" /*Forced Steam name reset*/
#include "name/nameadmin.sp" /*Name admin interface*/

/******************************
INITIATE THE PLUGIN
******************************/
public void OnPluginStart()
{
	/***STOP PLUGIN IF USED ON CS:GO***/
	
	EngineVersion engine = GetEngineVersion();
	
	if (engine != Engine_HL2DM)
	{
		SetFailState("Plugin \"Change Your Name\" is intended for Half-Life 2: Deathmatch. Check that you are using the correct version for the game you are running this dedicated server for.");
		LogError("Attempt to load a version of \"Change Your Name\" on an unsupported game. Check that the correct version of this plugin is being used.");
	}
	
	/***STOP PLUGIN IF OTHER NAME PLUGIN IS FOUND***/
	
	if (FindPluginByFile("sm_name.smx") != null)
	{
		SetFailState("Plugin conflict: sm_name.smx - Plugin delivers similar functions as plugin \"Change Your Name\". Please use one version only.");
		LogError("Plugin conflict: sm_name.smx - Cannot use both at once. ");
	}
	
	/***We need to make sure they run the cl_playermodel fix for a smoother experience***/
	
	if (!FindPluginByFile("hl2mp_cl_playermodel_fix.smx"))
	{
		SetFailState("Plugin \"Change Your Name\" requires \"HL2MP - Playermodel Fix\" to function properly.");
		LogError("\"HL2MP - Playermodel Fix\" missing, plugin halted.");
	}
	
	/*If no errors occured, move on to pre-setup*/
	
	g_names = CreateTrie(); /*Hashmap*/
	
	/*Create our arrays*/
	
	hBadNames = new ArrayList(ByteCountToCells(MAX_NAME_LENGTH));
	hBannedSteamId = new ArrayList(ByteCountToCells(MAX_NAME_LENGTH));
	
	/*We want to hook player_changename in order to block the default message from showing. Only valid for games that use that. For games like CSS or CSGO, we will use a different method.*/
	
	if (!HookEventEx("player_changename", namechange_callback, EventHookMode_Pre))
	{
		SetFailState("Event player_changename does not exist. Unloading...");
		LogError("Event player_changename does not exist. Plugin unloaded.");
	}
	
	/*Failsafe*/
	
	g_bMapReload = false;
	
	/*For "nameadmin player status" for statistics*/
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			g_iClients[i] = GetClientUserId(i);
		}
	}
	
	/*Admin menus*/
	
	TopMenu topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != null))
	{
		OnAdminMenuReady(topmenu);
	}
	
	/*Updater*/
	
	if (LibraryExists("updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
	
	/*Loading files*/
	
	LoadTranslations("common.phrases"); /*Basic Sourcemod translations*/
	/*Plugin translations will come at a later time*/
	
	/*Load files containing banned names and SteamIDs*/
	
	BuildPath(Path_SM, fileName, sizeof(fileName), "configs/banned_names.ini");
	BuildPath(Path_SM, bannedidfile, sizeof(bannedidfile), "configs/banned_id.ini");
	
	/***PLUGIN STATISTICS STUFF***/
	
	/*Initialize the name tracking counter and set the timezone*/
	
	g_iNameChangeTracker = 0;
	g_iNameResetTracker = 0;
	g_iRenameTracker = 0;
	g_iOnameTracker = 0;
	g_iSnameTracker = 0;
	g_iSrnameTracker = 0;
	g_iSteamQueryFail = 0;
	g_iForcedNames = 0;
	
	/***COMMANDS SETUP***/
	
	/*Plugin version*/
	
	CreateConVar("sm_name_version", PLUGIN_VERSION, "Plugin Version (DO NOT CHANGE)", FCVAR_DONTRECORD | FCVAR_SPONLY | FCVAR_ARCHIVE);
	
	/*ConVar*/
	
	changename_cooldown = CreateConVar("sm_name_cooldown", "30", "Time before letting players change their name again.", 0, true, 10.0);
	changename_enable_global = CreateConVar("sm_name_enable", "1", "Enable/Disable plugin.", 0, true, 0.0, true, 1.0);
	changename_enable = CreateConVar("sm_cname_enable", "1", "Enable/Disable name changes.", 0, true, 0.0, true, 1.0);
	originalname_enable = CreateConVar("sm_oname_enable", "1", "Enable/Disable fetching a player's join name.", 0, true, 0.0, true, 1.0);
	steamname_enable = CreateConVar("sm_sname_enable", "1", "Enable/Disable checking players Steam name.", 0, true, 0.0, true, 1.0);
	changename_steamreset = CreateConVar("sm_srname_enable", "1", "Enable/Disable Steam name resets.", 0, true, 0.0, true, 1.0);
	changename_help = CreateConVar("sm_hname_enable", "1", "Enable/Disable name help messages.", 0, true, 0.0, true, 1.0);
	changename_bantime = CreateConVar("sm_name_ban_time", "-2", "Controls the length of the ban. Use \"-1\" to kick, \"-2\" to display a message to the player.", 0, true, -2.0);
	changename_banreason = CreateConVar("sm_name_ban_reason", "This name is banned from being used. Please change it.", "What message to display on kick/ban.");
	changename_adminrename_cooldown = CreateConVar("sm_rename_cooldown", "600", "Controls how long a player needs to wait before changing their name again after an admin renamed them.", 0, true, 10.0);
	
	//Hooking Cvars
	
	HookConVarChange(changename_enable_global, OnConVarChanged_Global);
	HookConVarChange(changename_enable, OnConVarChanged_Name);
	HookConVarChange(originalname_enable, OnConVarChanged_Oname);
	HookConVarChange(steamname_enable, OnConVarChanged_Sname);
	HookConVarChange(changename_steamreset, OnConVarChanged_Srname);
	HookConVarChange(changename_adminrename_cooldown, OnConVarChanged_AdminRename);
	HookConVarChange(changename_cooldown, OnConVarChanged_NameCooldown);
	HookConVarChange(changename_help, OnConVarChanged_NameHelp);
	HookConVarChange(changename_bantime, OnConVarChanged_BanTime);
	HookConVarChange(changename_banreason, OnConVarChanged_BanReason);
	
	/*Admin commands*/
	
	RegAdminCmd("sm_name_ban", Command_NameBan, ADMFLAG_BAN, "sm_name_ban <name to ban> - Bans a name from being used.");
	RegAdminCmd("sm_name_unban", Command_NameUnban, ADMFLAG_BAN, "sm_name_unban <name to unban> - Unbans a name from being used.");
	RegAdminCmd("sm_name_banid", Command_SteamidBan, ADMFLAG_BAN, "sm_name_banid <Steam ID to ban> - Bans a Steam ID whose user can no longer change name.");
	RegAdminCmd("sm_name_unbanid", Command_SteamidUnban, ADMFLAG_BAN, "sm_name_unbanid <Steam ID to unban> - Unbans a Steam ID whose user can no longer change name.");
	RegAdminCmd("sm_name_refresh", Command_Refresh, ADMFLAG_GENERIC, "sm_name_refresh - Refreshes banned names and Steam ID files.");
	RegAdminCmd("sm_name_history", Command_NameHistory, ADMFLAG_GENERIC, "sm_name_history <#userid|name> - Displays the last 10 names used by this player.");
	RegAdminCmd("sm_rename", Command_Rename, ADMFLAG_SLAY, "sm_rename <#userid|name> <new name> - Renames a player.");
	RegAdminCmd("sm_rename_random", Command_RenameRandom, ADMFLAG_SLAY, "sm_rename_random <#userid|name> - Randomly generates a name on the selected target.");
	RegAdminCmd("sm_rename_force", Command_NameForce, ADMFLAG_SLAY, "sm_rename_force <#userid|name> <name to force> - Forces a player to keep a name.");
	RegAdminCmd("sm_rename_unforce", Command_NameUnforce, ADMFLAG_SLAY, "sm_rename_unforce <#userid|name> - Removes forced name restrictions on a player.");
	RegAdminCmd("sm_rename_reset", Command_NameReset, ADMFLAG_GENERIC, "sm_rename_reset <#userid|name> - Resets a player's name.");
	RegAdminCmd("nameadmin", Command_NameAdmin, ADMFLAG_ROOT, "nameadmin <command> [arguments] - Administration system for the name plugin");
	
	/*Public commands*/
	
	RegConsoleCmd("sm_name", Command_Name, "sm_name <new name> (Leave blank to reset name).");
	RegConsoleCmd("sm_oname", Command_Oname, "sm_oname <#userid|name> - Find a player's join name.");
	RegConsoleCmd("sm_sname", Command_Sname, "sm_sname <#userid|name> - Find the Steam name of a player.");
	RegConsoleCmd("sm_srname", Command_Srname, "sm_srname - Resets a player's name to their Steam name.");
	RegConsoleCmd("sm_name_help", Command_Hname, "sm_name_help - Prints public commands.");
	RegConsoleCmd("sm_name_credits", Command_Credits, "sm_name_credits - Display credits listing.");
	
	PrintToServer("Plugin \"Change Your Name\" is active. Players may change their name at will while in the server.");
	
	Name_History();
	
	AutoExecConfig(true, "sm_name");
}

/******************************
PULUGIN FUNCTIONS
******************************/

public void OnLibraryAdded(const char[] sName)
{
	if (StrEqual(sName, "updater"))
	{
		Updater_AddPlugin(UPDATE_URL);
	}
}

/*Suppress the default name change messages*/
public Action namechange_callback(Event event, const char[] name, bool dontBroadcast)
{
	if (!GetConVarBool(changename_enable_global))
		return Plugin_Continue; /*Print if plugin is disabled*/
	
	char buffer[MAX_NAME_LENGTH];
	GetEventString(event, "newname", buffer, sizeof(buffer));
	LogMessage("[CNE] - %L changed their name to %s", GetClientOfUserId(GetEventInt(event, "userid")), buffer); /*CNE == Change Name Event*/
	NameCheck(buffer, GetClientOfUserId(GetEventInt(event, "userid")));
	
	SetEventBroadcast(event, true);
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client || IsFakeClient(client))
		return Plugin_Continue;
	
	return Plugin_Changed; /*Do not print to chat default name change messages*/
}

public void OnAdminMenuReady(Handle aTopMenu)
{
	TopMenu topmenu = TopMenu.FromHandle(aTopMenu);
	
	/* Block us from being called twice */
	if (topmenu == hAdminMenu)
	{
		return;
	}
	
	hAdminMenu = topmenu;
	
	TopMenuObject player_commands = hAdminMenu.FindCategory(ADMINMENU_PLAYERCOMMANDS);
	
	if (player_commands != INVALID_TOPMENUOBJECT)
	{
		hAdminMenu.AddItem("sm_name_banid", AdminMenu_NameBanId, player_commands, "sm_ban", ADMFLAG_BAN);
		hAdminMenu.AddItem("sm_name_random", AdminMenu_RenameRandom, player_commands, "sm_ban", ADMFLAG_BAN);
		hAdminMenu.AddItem("sm_name_history", AdminMenu_NameHistory, player_commands, "sm_ban", ADMFLAG_BAN);
		hAdminMenu.AddItem("sm_name_reset", AdminMenu_NameReset, player_commands, "sm_admin", ADMFLAG_GENERIC);
	}
}

public void OnMapStart()
{
	g_names.Clear();
	hBadNames.Clear();
	hBannedSteamId.Clear();
	
	BuildPath(Path_SM, fileName, sizeof(fileName), "configs/banned_names.ini");
	BuildPath(Path_SM, bannedidfile, sizeof(bannedidfile), "configs/banned_id.ini");
	
	/*Banned names file*/
	Handle file = OpenFile(fileName, "a+");
	
	if (!file)
	{
		LogError("Banned names file (%s) could not be opened (Path_SM/config/banned_names.ini).", fileName);
		return;
	}
	
	if (file)
	{
		PrintToServer("Successfully loaded banned_names.ini. Players will not be able to use names in file.");
	}
	
	char line[MAX_NAME_LENGTH], bannedline[MAX_NAME_LENGTH];
	while (!IsEndOfFile(file))
	{
		if (!ReadFileLine(file, line, sizeof(line)))
		{
			break;
		}
		
		TrimString(line);
		ReplaceString(line, sizeof(line), " ", "");
		
		if (!strlen(line) || (line[0] == '/' && line[1] == '/'))
		{
			continue;
		}
		
		hBadNames.PushString(line);
	}
	
	PrintToServer("[config/banned_names.ini] Loaded banned names: %i", hBadNames.Length);
	
	CloseHandle(file);
	
	/*Banned Steam IDs file*/
	Handle idfile = OpenFile(bannedidfile, "a+");
	
	if (!idfile)
	{
		LogError("Banned Steam IDs file (%s) could not be opened (Path_SM/config/banned_id.ini).", bannedidfile);
		return;
	}
	
	if (idfile)
	{
		PrintToServer("Successfully loaded banned_id.ini. SteamIDs in this file are blocked from using commands with plugin \"Change Your Name\".");
	}
	
	while (!IsEndOfFile(idfile))
	{
		if (!ReadFileLine(idfile, bannedline, sizeof(bannedline)))
		{
			break;
		}
		
		TrimString(bannedline);
		ReplaceString(bannedline, sizeof(bannedline), " ", "");
		
		if (!strlen(bannedline) || (bannedline[0] == '/' && bannedline[1] == '/'))
		{
			continue;
		}
		
		hBannedSteamId.PushString(bannedline);
	}
	
	PrintToServer("[config/banned_id.ini] Loaded banned Steam IDs: %i", hBannedSteamId.Length);
	
	CloseHandle(idfile);
	
	for (int i = 1; i < MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		char name[MAX_NAME_LENGTH];
		GetClientName(i, name, sizeof(name));
		NameCheck(name, i);
	}
}

public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;
		
		g_hTimer[i] = null;
		g_hNameReset[i] = null;
		g_hNameChange[i] = null;
	}
}

public void OnPluginEnd()
{
	LogMessage("Plugin was unloaded. Dumping latest information to the Sourcemod logs:\n\
	Number of name changes: %i\n\
	Number of name resets: %i\n\
	Number of admin renames: %i\n\
	Number of forced names set: %i\n\
	Number of Steam name resets: %i\n\
	Number of join names checked: %i\n\
	Number of Steam names checked: %i\n", 
		g_iNameChangeTracker, 
		g_iNameResetTracker, 
		g_iRenameTracker, 
		g_iForcedNames, 
		g_iSrnameTracker, 
		g_iOnameTracker, 
		g_iSnameTracker, 
		g_iSrnameTracker);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i) || IsFakeClient(i))
		{
			LogMessage("No players were connected at this time.");
			return;
		}
		char name[MAX_NAME_LENGTH], id[32];
		GetClientName(i, name, sizeof(name));
		GetClientAuthId(i, AuthId_Steam2, id, sizeof(id));
		LogMessage("Dumping per player information to the Sourcemod logs:\n\
		Player: %s - %s\n\
		Number of name changes: %i\n\
		Number of name resets: %i\n\
		Number of admin renames: %i\n\
		Number of forced names set: %i\n\
		Number of Steam name resets: %i\n\
		Number of !oname usage: %i\n\
		Number of !sname usage: %i\n\
		Number of failed queries: %i\n\
		Number of times player was checked by another player for Steam name: %i\n\
		Number of times player was checked by another player for join name: %i\n", 
			name, 
			id, 
			g_iChangedMyName[i], 
			g_iResetMyName[i], 
			g_iWasRenamed[i], 
			g_iWasForcedNamed[i], 
			g_iResetToSteam[i], 
			g_iCheckedOname[i], 
			g_iCheckedSname[i], 
			g_iCouldNotQuery[i], 
			g_iTargetWasSteamChecked[i], 
			g_iTargetWasOnameChecked[i]);
		
		g_hTimer[i] = null;
		g_hNameReset[i] = null;
		g_hNameChange[i] = null;
		return;
	}
}

public void OnClientConnected(int client)
{
	g_bClientAuthorized[client] = true;
}

public void OnClientPutInServer(int client)
{
	g_bAdminRenamed[client] = false;
	g_bForcedName[client] = false;
	
	// Player joins => Total time played is 0:00:00 (H:MM:SS)
	if (g_iClients[client] != GetClientUserId(client))
	{
		g_iClients[client] = GetClientUserId(client);
		if (!IsFakeClient(client))
		{
			g_iTimeTotal[client] = RoundToZero(GetClientTime(client));
		}
	}
}

public void OnClientPostAdminCheck(int client)
{
	char id[64], name[MAX_NAME_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, id, sizeof(id));
	GetClientName(client, name, sizeof(name));
	g_names.SetString(id, name);
	g_bClientAuthorized[client] = false;
	LogMessage("%s was verified. Steam ID (%s) and name stored in memory.", name, id);
	
	NameCheck(name, client);
	IdCheck(id, client);
	
	PrintToChat(client, "[SM] This server allows name changes. Type !name_help for more information.");
}

public void OnClientDisconnect(int client)
{
	delete g_hNameReset[client];
	delete g_hNameChange[client];
	delete g_hForceLockSteamCheck[client];
	delete g_hTimer[client];
}

/******************************
PLUGIN GENERAL CUSTOM VOIDS
******************************/

void NameCheck(char[] clientName, int player)
{
	if (!player || CheckCommandAccess(player, "sm_admin", ADMFLAG_GENERIC))
	{
		return;
	}
	
	ReplaceString(clientName, MAX_NAME_LENGTH, " ", "");
	
	char buffer[MAX_NAME_LENGTH], permaname[MAX_NAME_LENGTH];
	char bantime = GetConVarInt(changename_bantime);
	char reason[128];
	GetConVarString(changename_banreason, reason, 128);
	
	for (int i, num = hBadNames.Length; i < num; i++)
	{
		if (hBadNames.GetString(i, buffer, sizeof(buffer)) && StrContains(clientName, buffer, false) != -1)
		{
			if (FindPluginByFile("sbpp_main.smx"))
			{
				if (bantime > -1)
				{
					ShowActivity2(player, "[SM] ", "Banned %s for %i minute%s [Joined with a banned name].", clientName, bantime, bantime <= 1 ? "" : "s");
					LogMessage("Auto-banned %s (joining with a banned name).", clientName);
					SBPP_BanPlayer(0, player, bantime, reason);
				}
			}
			
			else
			{
				BanClient(player, bantime, BANFLAG_AUTO, reason, reason);
			}
			
			if (bantime == -1)
			{
				KickClient(player, reason);
			}
			
			if (bantime == -2)
			{
				SetClientName(player, "<NAME REMOVED>");
				PrintToChat(player, "[SM] Your name has been removed, because it is banned on this server.");
				if (GetClientInfo(player, "permaname", permaname, sizeof(permaname)))PrintToChat(player, "[SM] Could not set your permanent name due to a name removal.");
				LogMessage("Name %s removed (banned in banned_names.ini).", clientName);
			}
		}
		return;
	}
	
	if (!GetClientInfo(player, "permaname", permaname, sizeof(permaname)))
		return;
	
	if (strlen(permaname) < 1)return;
	if (StrEqual(permaname, " "))return;
	
	SetClientInfo(player, "name", permaname);
	
	LogMessage("%L joined server with a permanent name: %s", player, permaname);
	return;
}

void IdCheck(char getsteamid[64], int player)
{
	if (!player || CheckCommandAccess(player, "sm_admin", ADMFLAG_GENERIC))
		return;
	
	ReplaceString(getsteamid, 64, " ", "");
	
	char buffer[MAX_NAME_LENGTH];
	for (int i, num = hBannedSteamId.Length; i < num; i++)
	{
		if (hBannedSteamId.GetString(i, buffer, sizeof(buffer)) && StrContains(getsteamid, buffer, false) != -1)
		{
			PrintToChat(player, "[SM] Your Steam ID is banned from changing names.");
			LogMessage("%N (%s) is banned from changing names.", player, getsteamid);
		}
	}
}

void Name_History()
{
	char sPlayerNameHistory[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPlayerNameHistory, sizeof(sPlayerNameHistory), "Name");
	
	if (!DirExists(sPlayerNameHistory))
	{
		CreateDirectory(sPlayerNameHistory, 511);
		PrintToServer("Folder \"Name\" created. Player name history enabled.");
	}
}

/******************************
CONVARS HOOKED
******************************/

/*FCVAR_NOTIFY could have done the job, but I wanted proper SM messages, not that garbage from the engine "Server cvar" that makes no sense in this context.*/

public void OnConVarChanged_Global(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp(newValue, "1") == 0)
	{
		PrintToServer("[SM] This plugin is now enabled.");
		PrintToChatAll("[SM] Plugin \"Change Your Name\" is now enabled.");
		return;
	}
	if (strcmp(newValue, "0") == 0)
	{
		PrintToServer("[SM] This plugin is now disabled.");
		PrintToChatAll("[SM] Plugin \"Change Your Name\" is now disabled.");
		return;
	}
}

public void OnConVarChanged_Name(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp(newValue, "1") == 0)
	{
		PrintToServer("[SM] Players can no longer change their name with this plugin.");
		PrintToChatAll("[SM] Players can no longer change their name with this plugin.");
	}
	if (strcmp(newValue, "0") == 0)
	{
		PrintToServer("[SM] Players can now change their name with this plugin.");
		PrintToChatAll("[SM] Players can now change their name with this plugin.");
		return;
	}
}

public void OnConVarChanged_Oname(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp(newValue, "1") == 0)
	{
		PrintToServer("[SM] Players can no longer fetch other players join names.");
		PrintToChatAll("[SM] Players can no longer fetch other players join names.");
		return;
	}
	if (strcmp(newValue, "0") == 0)
	{
		PrintToServer("[SM] Players can now fetch other players join names.");
		PrintToChatAll("[SM] Players can now fetch other players join names.");
		return;
	}
}

public void OnConVarChanged_Sname(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp(newValue, "1") == 0)
	{
		PrintToServer("[SM] Players can no longer fetch other players Steam names.");
		PrintToChatAll("[SM] Players can no longer fetch other players Steam names.");
		return;
	}
	if (strcmp(newValue, "0") == 0)
	{
		PrintToServer("[SM] Players can now fetch other players Steam names.");
		PrintToChatAll("[SM] Players can now fetch other players Steam names.");
		return;
	}
}

public void OnConVarChanged_Srname(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp(newValue, "1") == 0)
	{
		PrintToServer("[SM] Players can no longer reset to their Steam names.");
		PrintToChatAll("[SM] Players can no longer reset to their Steam names.");
		return;
	}
	if (strcmp(newValue, "0") == 0)
	{
		PrintToServer("[SM] Players can no longer reset to their Steam names.");
		PrintToChatAll("[SM] Players can no longer reset to their Steam names.");
		return;
	}
}

public void OnConVarChanged_NameCooldown(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int timeleft = GetConVarInt(changename_cooldown);
	int mins, secs;
	if (timeleft > 0)
	{
		mins = timeleft / 60;
		secs = timeleft % 60;
		PrintToServer("[SM] Name cooldown changed to %d:%02d.", mins, secs);
		PrintToChatAll("[SM] Name cooldown changed to %d:%02d.", mins, secs);
	}
	
	return;
}

public void OnConVarChanged_AdminRename(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int timeleft = GetConVarInt(changename_adminrename_cooldown);
	int mins, secs;
	if (timeleft > 0)
	{
		mins = timeleft / 60;
		secs = timeleft % 60;
		PrintToServer("[SM] Rename cooldown changed to %d:%02d.", mins, secs);
		PrintToChatAll("[SM] Rename cooldown changed to %d:%02d.", mins, secs);
	}
	
	return;
}

public void OnConVarChanged_NameHelp(ConVar convar, const char[] oldValue, const char[] newValue)
{
	PrintToServer("[SM] Cvar \"sm_hname_enable\" changed to \"%s\".", GetConVarBool(changename_help));
	PrintToChatAll("[SM] Cvar \"sm_hname_enable\" changed to \"%s\".", GetConVarBool(changename_help));
	
	return;
}

public void OnConVarChanged_BanTime(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (strcmp(newValue, "-2") == 0)
	{
		PrintToServer("[SM] Name ban time updated. Banned names will only be removed.");
		PrintToChatAll("[SM] Name ban time updated. Banned names will only be removed.");
		return;
	}
	
	if (strcmp(newValue, "-1") == 0)
	{
		PrintToServer("[SM] Name ban time updated. Players with banned names will get kicked.");
		PrintToChatAll("[SM] Name ban time updated. Players with banned names will get kicked.");
		return;
	}
	
	else
	{
		PrintToServer("[SM] Name ban time updated: %i minute%s.", GetConVarInt(changename_bantime), GetConVarInt(changename_bantime) <= 1 ? "" : "s");
		PrintToChatAll("[SM] Name ban time updated: %i minute%s.", GetConVarInt(changename_bantime), GetConVarInt(changename_bantime) <= 1 ? "" : "s");
		return;
	}
}

public void OnConVarChanged_BanReason(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char buffer[128];
	GetConVarString(changename_banreason, buffer, sizeof(buffer));
	PrintToServer("[SM] Name ban reason updated to \"%s\"", buffer);
	
	return;
}

/******************************
PLUGIN STOCKS (Printing to admins whenever the plugin gets reloaded through "nameadmin plugin reload [map_reload]")
******************************/
/*No longer needed, but left here just in case*/
/*int PrintToAdmins(char[] format)
{
	char buffer[1024];
	VFormat(buffer, sizeof(buffer), format, 2);
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i))
		{
			int admin = GetUserFlagBits(i);
			if (admin != 0 && admin > 1)
			{
				
				PrintToChat(i, "%s", buffer);
			}
		}
	}
	return 0;
}*/