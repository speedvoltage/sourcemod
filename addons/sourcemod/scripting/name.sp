/******************************
INCLUDE ALL THE NECESSARY FILES
******************************/

#include <sourcemod>
#include <sdktools>

/******************************
COMPILE OPTIONS
******************************/

#pragma semicolon 1
#pragma newdecls required

/******************************
PLUGIN DEFINES
******************************/

/*Plugin Info*/
#define PLUGIN_NAME								"Set My Name"
#define PLUGIN_AUTHOR							"Peter Brev (Base code provided by Harper)"
#define PLUGIN_VERSION							"1.5.0.1938" //Build number since 05/12/18
#define PLUGIN_DESCRIPTION						"Allows players to use a new name"
#define PLUGIN_URL								"https://peterbrev.info"

/*Plugin defines for messages*/
#define TAG									"[NAME]"
#define CTAG 									"\x0729e313"
#define CUSAGE 								"\x0700ace6"
#define CERROR 								"\x07ff2700"
#define CLIME									"\x0700ff15"
#define CPLAYER								"\x07ffb200"

/*Player name changes messages*/
#define CS_NAME_CHANGE_STRING "#Cstrike_Name_Change"
#define TF_NAME_CHANGE_STRING "#TF_Name_Change"

/*Logging*/
#define LOGTAG									"[NAME DEBUG]"
#define CLOGTAG								"\x078e8888"
#define LOGPATH								"addons/sourcemod/logs/NameChanger/NameChanger.log"

/*Sound*/
#define MAX_FILE_LEN							80

/*Boolean for EventHook*/

bool EventsHook = false;
bool bChanging[MAXPLAYERS+1];

bool gB_HideNameChange = false;

/******************************
PLUGIN STRINGMAPS
******************************/

StringMap g_names;
StringMap g_bannednames;
StringMap g_bannedids;

/******************************
PLUGIN HANDLES
******************************/

Handle changename_help;
Handle steamname_enable;
Handle changename_version;
Handle changename_enable_global;
Handle changename_enable;
Handle originalname_enable;
Handle changename_debug;
Handle changename_steamreset;
Handle changename_bantime;
Handle changename_banreason;
Handle changename_cooldown = INVALID_HANDLE;
Handle changename_adminrename_cooldown = INVALID_HANDLE;
Handle changename_checkbadnames;
Handle changename_checkbannedids;

//Sound Handles
Handle changename_debug_snd;

Handle changename_debug_snd_warn_on = INVALID_HANDLE;
Handle changename_debug_snd_warn_off = INVALID_HANDLE;

/******************************
PLUGIN INTEGERS
******************************/

int g_iLastUsed[MAXPLAYERS+1];
int g_renamed[MAXPLAYERS+1];

/******************************
PLUGIN STRINGS
******************************/

char g_SoundName_On[MAX_FILE_LEN];
char g_SoundName_Off[MAX_FILE_LEN];

char BadNames[255][64];
char fileName[PLATFORM_MAX_PATH];
char lines;

char bannedsteamids[255][64];
char bannedidfile[PLATFORM_MAX_PATH];
char bannedlines;

char adminrenamedid[255][64];
char adminrenamedfile[PLATFORM_MAX_PATH];
char adminrenamedlines;

char g_targetnewname[MAXPLAYERS+1][MAX_NAME_LENGTH];

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
	/***STOP PLUGIN IF OTHER NAME PLUGIN IS FOUND***/
	
	if (FindPluginByFile("sm_name.smx") != null)
	{
		ThrowError("%s You are using a plugin from Eyal282 that delivers the same function. You cannot run both at once!", TAG);
		LogError("Attempt to load both \"sm_name.smx\" and \"name.smx\". This is invalid!");
	}
	
	/***PRE-SETUP***/
	
	g_names = CreateTrie();
	g_bannednames = CreateTrie();
	g_bannedids = CreateTrie();
	
	//We want to hook player_changename in order to block the default message from showing
	
	bool exists = HookEventEx("player_changename", namechange_callback, EventHookMode_Pre);
	if (!exists)
	{
		SetFailState("Event player_changename does not exist. Unloading...");
	}
	
	//Finally, load the translations
	
	LoadTranslations("common.phrases");
	//LoadTranslations("name.phrases"); Something broke translations. They used to work fine before, now they don't. I'll take another look eventually.
	
	BuildPath(Path_SM, fileName, sizeof(fileName), "configs/banned_names.ini");
	BuildPath(Path_SM, bannedidfile, sizeof(bannedidfile), "configs/banned_id.ini");
	BuildPath(Path_SM, adminrenamedfile, sizeof(adminrenamedfile), "configs/admin_renamed_temp.ini");

	/***COMMANDS SETUP***/
	
	//Create a convar for plugin version & with the help of the handle, go ahead and put the proper version
	
	changename_version = CreateConVar("sm_name_version", PLUGIN_VERSION, "Plugin Version (DO NOT CHANGE)", FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DEVELOPMENTONLY);
	
	SetConVarString(changename_version, PLUGIN_VERSION);
	
	//Create ConVars
	
	//General
	changename_help = CreateConVar("sm_name_help_enable", "1", "Controls whether the plugin should print a help message when clients join", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	changename_enable_global = CreateConVar("sm_name_enable", "1", "Controls whether the plugin should be enabled or disabled", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	changename_enable = CreateConVar("sm_cname_enable", "1", "Controls whether players can change their name", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	originalname_enable = CreateConVar("sm_oname_enable", "1", "Controls whether players can check original name of players", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	steamname_enable = CreateConVar("sm_sname_enable", "1", "Controls whether players can check Steam name of players", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	changename_steamreset = CreateConVar("sm_srname_enable", "1", "Controls whether players can reset their name to their Steam name", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	changename_bantime = CreateConVar("sm_name_ban_time", "-2", "Controls the length of the ban. Use \"-1\" to kick, \"-2\" to display a message to the player.", FCVAR_NOTIFY);
	changename_banreason = CreateConVar("sm_name_ban_reason", "[AUTO-DISCONNECT] This name is inappropriate. Please change it.", "What message to display on kick/ban.");
	changename_cooldown = CreateConVar("sm_name_cooldown", "30", "Time before letting players change their name again.", FCVAR_NOTIFY);
	changename_checkbadnames = CreateConVar("sm_name_bannednames_checker", "1", "Controls whether banned names should be filtered.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	changename_checkbannedids = CreateConVar("sm_name_bannedids_checker", "1", "Controls whether banned Steam IDs should be checked.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	changename_adminrename_cooldown = CreateConVar("sm_rename_cooldown", "60", "Controls how long a player needs to wait before changing their name again after an admin renamed them.", FCVAR_NOTIFY);
	
	//Technical
	changename_debug = CreateConVar("sm_name_debug", "0", "Toggles logging for debugging purposes (Only use this if you are experiencing weird issues)", 0, true, 0.0, true, 1.0); //Allows us to debug in case of an issue with the plugin
	changename_debug_snd = CreateConVar("sm_name_debug_snd", "1", "Sets whether to play a sound when debug mode is toggle on or off", 0, true, 0.0, false, 1.0);
	changename_debug_snd_warn_on = CreateConVar("sm_name_debug_snd_on", "hl1/fvox/bell.wav", "Sets the sound to let admins know debug mode has been turned on");
	changename_debug_snd_warn_off = CreateConVar("sm_name_debug_snd_off", "hl1/fvox/beep.wav", "Sets the sound to let admins know debug mode has been turned off");
	
	
	//Hooking Cvars
	HookConVarChange(changename_debug, OnConVarChanged_Debug); //If debug value was changed, let the server operator know
	HookConVarChange(changename_enable_global, OnConVarChanged_Global);
	HookConVarChange(changename_enable, OnConVarChanged_Name);
	HookConVarChange(originalname_enable, OnConVarChanged_Oname);
	HookConVarChange(steamname_enable, OnConVarChanged_Sname);
	HookConVarChange(changename_debug_snd, OnConVarChanged_Snd);
	HookConVarChange(changename_debug_snd_warn_on, OnConVarChanged_SndOn);
	HookConVarChange(changename_debug_snd_warn_off, OnConVarChanged_SndOff);
	HookConVarChange(changename_steamreset, OnConVarChanged_Srname);
	HookConVarChange(changename_checkbadnames, OnConVarChanged_NameCheck);
	HookConVarChange(changename_checkbannedids, OnConVarChanged_IdCheck);
	
	HookEvent("player_team", Event_TeamChange, EventHookMode_Pre);
	
	HookUserMessage(GetUserMessageId("SayText2"), Hook_SayText2, true);
	
	//Listners (We are using this for !srname (Steam Reset name) to go around a little bug with the engine. This is why we do not register a public command for it
	/*AddCommandListener(OnClientCommands, "say");
	AddCommandListener(OnClientCommands, "say_team");*/
	//Steam name reset is now a normal console command.
	
	parseList_Name(false);
	parseList_id(false);
	
	//Create the admin commands
	RegAdminCmd("sm_name_ban", Command_NameBan, ADMFLAG_BAN, "sm_name_ban <name to ban (NO SPACES)>");
	RegAdminCmd("sm_name_unban", Command_NameUnban, ADMFLAG_BAN, "sm_name_unban <name to unban (NO SPACES)>");
	RegAdminCmd("sm_name_banid", Command_SteamidBan, ADMFLAG_BAN, "sm_name_banid <SteamID to ban");
	RegAdminCmd("sm_name_unbanid", Command_SteamidUnban, ADMFLAG_BAN, "sm_name_unbanid <SteamID to unban");
	RegAdminCmd("sm_name_reload", Command_FilesRefresh, ADMFLAG_BAN, "Reloads banned_names.ini and banned_id.ini");
	RegAdminCmd("sm_rename", Command_Rename, ADMFLAG_SLAY, "Renames a player manually and apply a temporary cooldown before being able to change names again.");
	
	//Create the public commands
	RegConsoleCmd("sm_name", Command_Name, "sm_name <new name> (Leave blank to reset to join name or Steam name)");
	RegConsoleCmd("sm_oname", Command_Oname, "sm_oname <#userid|name> - Find the original name of a player upon connection");
	RegConsoleCmd("sm_sname", Command_Sname, "sm_sname <#userid|name> - Find the Steam name of a player");
	RegConsoleCmd("sm_srname", Command_Srname);
	RegConsoleCmd("sm_nhelp", Command_Hname, "sm_name_help - Prints commands to the clients console");
	RegConsoleCmd("sm_name_credits", Command_Credits);
	
		
	//Configs
	AutoExecConfig(true, "sm_name");
	
	/***DEBUGGING SETUP***/
	
	//We are just creating a directory for our log files to be stored in instead of using Sourcemod's logging system, so that it is easier to debug
	
	if (GetConVarBool(changename_debug))
	{
		Debug_Path();
	}
	
	//Are we done here? Can we move to coding the real thing?
}

/******************************
PUBLIC CALLBACKS
******************************/ 

public Action Event_TeamChange(Event e, char[] sName, bool bBroadcast)
{
    // get the "userid" parameter from the event and convert this to a sourcemod client index
    int iClient = GetClientOfUserId(e.GetInt("userid"));
    
    // if the bool is true for this client
    if (bChanging[iClient])
    {
        // block the team change event
        bChanging[iClient] = false;
        return Plugin_Handled;
    }
    
    // in all other cases, the event proceeds as normal.
    return Plugin_Continue;
}
public Action ConVarChecker_Callback(Handle timer, any data)
{
	if (!GetConVarBool(changename_enable) && !GetConVarBool(originalname_enable) && !GetConVarBool(steamname_enable) && !GetConVarBool(changename_steamreset))
	{
		SetConVarFloat(changename_enable, 1.0, _, false);
		SetConVarFloat(originalname_enable, 1.0, _, false);
		SetConVarFloat(steamname_enable, 1.0, _, false);
		SetConVarFloat(changename_steamreset, 1.0, _, false);
		SetConVarFloat(changename_enable_global, 0.0, _, false);
		PrintToServer("%s ConVar \"sm_cname_enable\", \"sm_oname_enable\" and \"sm_sname_enable\" were set to 0. This is the same behavior as setting ConVar \"sm_name_enable\" to 0. All three ConVars were set to 1 and \"sm_name_enable\" was set to 0. Use 1 to enable the plugin again.", TAG);
		PrintToServer("%s This plugin is disabled. To turn it on, use \"sm_name_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Plugin is disabled due to ConVar \"sm_cname_enable\", \"sm_oname_enable\" and \"sm_sname_enable\" being turned off.", LOGTAG);
		}
	}	
	return Plugin_Handled;
}

public void OnMapStart()
{
	for (int i = 0; i < lines; i++)
	{
		BadNames[i] = "";
	}
	
	lines = 0;
	
	for (int y = 0; y < bannedlines; y++)
	{
		bannedsteamids[y] = "";
	}
	
	bannedlines = 0;
	
	for (int x = 0; x < adminrenamedlines; x++)
	{
		adminrenamedid[x] = "";
	}
	
	adminrenamedlines = 0;
	
	if (ReadConfig() && !EventsHook)
	{
		HookEvent("player_changename", checkName);
		EventsHook = true;
	}
	
	if (ReadBannedId() && !EventsHook)
	{
		HookEvent("player_changename", checkId);
		EventsHook = true;
	}
	
	if (AdminRenamed() && !EventsHook)
	{
		HookEvent("player_changename", adminrenamecheck);
		EventsHook = true;
	}
	
	if (changename_cooldown == INVALID_HANDLE)
	{
		SetFailState("%s You did not set a valid value for \"sm_name_cooldown\".", TAG);
	}
	
	if (changename_adminrename_cooldown == INVALID_HANDLE)
	{
		SetFailState("%s You did not set a valid value for \"sm_rename_cooldown\".", TAG);
	}
	
	if (GetConVarInt(changename_cooldown) < 1)
	{
		SetConVarInt(changename_cooldown, 30, _, true);
		PrintToServer("%s Cooldown value cannot be less than 1 second. Value reset to default (30 seconds).", TAG);
	}
	
	if (GetConVarInt(changename_adminrename_cooldown) < 1)
	{
		SetConVarInt(changename_adminrename_cooldown, 30, _, true);
		PrintToServer("%s Rename cooldown value cannot be less than 1 second. Value reset to default (30 seconds).", TAG);
	}
	
	if (!GetConVarBool(changename_enable_global))
	{
		PrintToServer("%s This plugin is disabled. To turn it on, use \"sm_name_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
		}
	} else if (!GetConVarBool(changename_enable))
	{
		PrintToServer("%s Name changing is disabled. To turn it on, use \"sm_cname_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Name changing disabled.", LOGTAG);
		}
	} else if (!GetConVarBool(originalname_enable))
	{
		PrintToServer("%s Fetching original names is disabled. To turn it on, use \"sm_oname_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Fetching original names disabled.", LOGTAG);
		}
	} else if (!GetConVarBool(steamname_enable))
	{
		PrintToServer("%s Fetching Steam names is disabled. To turn it on, use \"sm_sname_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Fetching Steam names disabled.", LOGTAG);
		}
	} else if (!GetConVarBool(changename_steamreset))
	{
		PrintToServer("%s Steam name reset ability is disabled. To turn it on, use \"sm_srname_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Reset to Steam name ability disabled.", LOGTAG);
		}
	} else if (!GetConVarBool(changename_enable) && !GetConVarBool(originalname_enable) && !GetConVarBool(steamname_enable) && !GetConVarBool(changename_steamreset))
	{
		SetConVarFloat(changename_enable, 1.0, _, false);
		SetConVarFloat(originalname_enable, 1.0, _, false);
		SetConVarFloat(steamname_enable, 1.0, _, false);
		SetConVarFloat(changename_steamreset, 1.0, _, false);
		SetConVarFloat(changename_enable_global, 0.0, _, false);
		PrintToServer("%s ConVar \"sm_cname_enable\", \"sm_oname_enable\" and \"sm_sname_enable\" were set to 0. This is the same behavior as setting ConVar \"sm_name_enable\" to 0. All three ConVars values were set to 1 and ConVar value \"sm_name_enable\" was set to 0. Use 1 to enable the plugin again.", TAG);
		PrintToServer("%s This plugin is disabled. To turn it on, use \"sm_name_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Plugin is disabled due to ConVars values \"sm_cname_enable\", \"sm_oname_enable\", \"sm_sname_enable\", and \"sm_srname_enable\" being set to 0.", LOGTAG);
		}
	} else if (!GetConVarBool(changename_enable_global) && !GetConVarBool(changename_enable) && !GetConVarBool(originalname_enable) && !GetConVarBool(steamname_enable) && !GetConVarBool(changename_steamreset))
	{
		SetConVarFloat(changename_enable, 1.0, _, false);
		SetConVarFloat(originalname_enable, 1.0, _, false);
		SetConVarFloat(steamname_enable, 1.0, _, false);
		SetConVarFloat(changename_steamreset, 1.0, _, false);
		SetConVarFloat(changename_enable_global, 0.0, _, false);
		PrintToServer("%s All ConVars values were set to 0. ConVar \"sm_cname_enable\", \"sm_oname_enable\", \"sm_sname_enable\", and \"sm_srname_enable\" values were set to 0 and ConVar \"sm_name_enable\" was set to 1.", TAG);
		PrintToServer("%s This plugin is disabled. To turn it on, use \"sm_name_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Plugin is disabled due to all ConVars values being set to 0. Setting \"sm_name_enable\" to 1.", LOGTAG);
		}
	}
	
	if (changename_debug_snd_warn_on == INVALID_HANDLE)
	{
		SetFailState("%s You did not set a valid sound file path for debug sound warn ON.");
	} else if (changename_debug_snd_warn_off == INVALID_HANDLE)
	{
		SetFailState("%s You did not set a valid sound file path for debug sound warn OFF.");
	}
	ConVarCheck();
}

public bool ReadConfig()
{
	//BuildPath(Path_SM, fileName, sizeof(fileName), "configs/banned_names.ini");
	Handle file = OpenFile(fileName, "rt");
	if (file == INVALID_HANDLE)
	{
		LogError("[NAME] Banned names file could not be opened.", fileName);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Banned names file could not be opened. Check that the file is placed in the \"configs\" folder.", LOGTAG);
		}
		return false;
	}
	
	if (file != INVALID_HANDLE)
	{
		PrintToServer("[NAME] Successfully loaded banned_names.ini", fileName);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Banned names file loaded.", LOGTAG);
		}
	}
	
	while(!IsEndOfFile(file))
	{
		char line[64];
		
		if (!ReadFileLine(file, line, sizeof(line)))
		{
			break;
		}
		
		TrimString(line);
		ReplaceString(line, 64, " ", "");
		
		if (strlen(line) == 0 || (line[0] == '/' && line[1] == '/'))
		{
			continue;
		}
		strcopy(BadNames[lines], sizeof(BadNames[]), line);
		lines++;
	}
	
	CloseHandle(file);
	return true;
}

public void OnClientPostAdminCheck(int client)
{
	char PlayerName[64];
	char getsteamid[64];
	
	if(!GetClientName (client, PlayerName, 64))
	{
		return;			
	}
	
	if(!GetClientAuthId (client, AuthId_Steam2, getsteamid, 64))
	{
		return;			
	}
	
	NameCheck(PlayerName, client);
	IdCheck(getsteamid, client);
	RenameCheck(getsteamid, client);
}

void NameCheck(char clientName[64], char player)
{
	char PlayerID = GetClientUserId(player);
	AdminId playerAdmin = GetUserAdmin(player);
	
	if(GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
	{
		return;
	}
	
	ReplaceString(clientName, 64, " ", "");
	
	for (int i = 0; i < lines; i++)
	{
		if (StrContains(clientName, BadNames[i], false) != -1)
		{
			char bantime = GetConVarInt(changename_bantime);
			char reason[64];
			GetConVarString(changename_banreason, reason, 64);
			if (GetConVarBool(changename_checkbadnames))
			{
				if (bantime > -1)
				{
					ServerCommand("sm_ban #%i %i %s", PlayerID, bantime, reason);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s was banned for using a banned name.", LOGTAG, clientName);
					}				
				}
				if (bantime == -2)
				{
					SetClientName(player, "<NAME REMOVED>");
					PrintToChat(player, "%s%s %sYour name has been removed, because it is banned on this server.", CTAG, TAG, CUSAGE);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s's name removed (banned name).", LOGTAG, clientName);
					}
				}	
				if (bantime == -1)
				{
					ServerCommand ("sm_kick #%i %s", PlayerID, reason);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s was kicked for using a banned name.", LOGTAG, clientName);
					}
				}
			}
		}
	}
	return;
}

public Action checkName(Event event, const char[] name, bool dontBroadcast)
{
	char PlayerName[64];
	GetEventString(event, "newname", PlayerName, 64);
	NameCheck(PlayerName, GetClientOfUserId(GetEventInt(event, "userid")));
	return Plugin_Handled;
}

public bool ReadBannedId()
{
	//BuildPath(Path_SM, bannedidfile, sizeof(bannedidfile), "configs/banned_id.ini");
	Handle file = OpenFile(bannedidfile, "rt");
	if (file == INVALID_HANDLE)
	{
		LogError("[NAME] Banned IDs file could not be opened.", bannedidfile);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Banned IDs file could not be opened. Check that the file is placed in the \"configs\" folder.", LOGTAG);
		}	
		return false;
	}
	
	if (file != INVALID_HANDLE)
	{
		PrintToServer("[NAME] Successfully loaded banned_id.ini", bannedidfile);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Banned Steam IDs file loaded.", LOGTAG);
		}
	}
	
	while(!IsEndOfFile(file))
	{
		char line[64];
		
		if (!ReadFileLine(file, line, sizeof(line)))
		{
			break;
		}
		
		TrimString(line);
		ReplaceString(line, 64, " ", "");
		
		if (strlen(line) == 0 || (line[0] == '/' && line[1] == '/'))
		{
			continue;
		}
		strcopy(bannedsteamids[bannedlines], sizeof(bannedsteamids[]), line);
		bannedlines++;
	}
	
	CloseHandle(file);
	return true;
}

public bool AdminRenamed()
{
	Handle file = OpenFile(adminrenamedfile, "rt");
	if (file == INVALID_HANDLE)
	{
		LogError("[NAME] Renamed players file could not be opened.", adminrenamedfile);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Renamed players file could not be opened. Check that the file is placed in the \"configs\" folder.", LOGTAG);
		}	
		return false;
	}
	
	if (file != INVALID_HANDLE)
	{
		PrintToServer("[NAME] Successfully loaded admin_renamed_temp.ini", adminrenamedfile);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Renamed players file loaded.", LOGTAG);
		}
	}
	
	while(!IsEndOfFile(file))
	{
		char line[64];
		
		if (!ReadFileLine(file, line, sizeof(line)))
		{
			break;
		}
		
		TrimString(line);
		ReplaceString(line, 64, " ", "");
		
		if (strlen(line) == 0 || (line[0] == '/' && line[1] == '/'))
		{
			continue;
		}
		strcopy(adminrenamedid[adminrenamedlines], sizeof(adminrenamedlines[]), line);
		adminrenamedlines++;
	}
	
	CloseHandle(file);
	return true;
}

void IdCheck(char getsteamid[64], char client)
{
	AdminId clientAdmin = GetUserAdmin(client);
	
	if(GetAdminFlag(clientAdmin, Admin_Generic, Access_Effective))
	{
		return;
	}
	
	ReplaceString(getsteamid, 64, " ", "");
	
	for (int i = 0; i < bannedlines; i++)
	{
		if (StrContains(getsteamid, bannedsteamids[i], false) != -1)
		{
			char bantime = GetConVarInt(changename_bantime);
			if (GetConVarBool(changename_checkbannedids))
			{
				if (bantime == -2)
				{
					PrintToChat(client, "%s%s %sYour Steam ID is banned from changing names.", CTAG, TAG, CUSAGE);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s attempted to change their name, but they are banned from doing so.", LOGTAG, client);
					}
				}
			}
		}
	}
	return;
}

void RenameCheck(char getsteamid[64], char client)
{
	AdminId clientAdmin = GetUserAdmin(client);
	
	if(GetAdminFlag(clientAdmin, Admin_Generic, Access_Effective))
	{
		return;
	}
	
	ReplaceString(getsteamid, 64, " ", "");
	
	/*for (int i = 0; i < adminrenamedlines; i++)
	{
		if (StrContains(getsteamid, adminrenamedid[i], false) != -1)
		{
			PrintToChat(client, "%s%s %sYou've recently been renamed by an admin and cannot change your name for a moment.", CTAG, TAG, CUSAGE);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %s attempted to change their name, but cannot due to having been renamed by an admin.", LOGTAG, client);
			}
		}
	}*/
	return;
}

public Action checkId(Event event, const char[] name, bool dontBroadcast)
{
	char PlayerName[64];
	GetEventString(event, "steamid2", PlayerName, 64);
	IdCheck(PlayerName, GetClientOfUserId(GetEventInt(event, "userid")));
	return Plugin_Handled;
}

public Action adminrenamecheck(Event event, const char[] name, bool dontBroadcast)
{
	char PlayerName[64];
	GetEventString(event, "steamid2", PlayerName, 64);
	RenameCheck(PlayerName, GetClientOfUserId(GetEventInt(event, "userid")));
	return Plugin_Handled;
}

public void OnMapEnd()
{
	if (GetConVarBool(changename_debug))
	{
		ResetConVar(changename_debug, false, false);
	}
}

public Action namechange_callback(Event event, const char[] name, bool dontBroadcast)
{
	
	if (GetConVarBool(changename_enable_global))
	{
		if (GetConVarBool(changename_enable))
		{
			SetEventBroadcast(event, true);
			int client = GetClientOfUserId(GetEventInt(event, "userid"));
			if(!client || IsFakeClient(client))
        		return Plugin_Continue;
    		
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s Default player name change messages suppressed.", LOGTAG);
			}
			return Plugin_Changed;    // avoid printing the change to the chat 
		}
	} else {
		SetEventBroadcast(event, false);
		if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s Default player name change messages was not suppressed due to ConVar \"sm_cname_enable\" being set to 0.", LOGTAG);
			}
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

//public void CheckCommands(int client, char[] string)
public Action Command_Srname(int client, int args)
{
	if (GetConVarBool(changename_enable_global))
	{
		if (GetConVarBool(changename_steamreset))
		{
			if (args > 0)
			{
				return Plugin_Handled;
			}
			
			if (!args)
			{
				QueryClientConVar(client, "name", ChangeNameToSteamName);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s %N has attempted a Steam name reset.", LOGTAG, client);
				}
				return Plugin_Handled;
			}
		}
		else
		{
			PrintToChat(client, "%s%s %sResetting to Steam name ability has been disabled.", CTAG, TAG, CERROR);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s Steam name reset ability disabled.", LOGTAG);
				LogToFile(LOGPATH, "%s %N attempted a Steam name reset but ability is disabled.", LOGTAG, client);
			}
			return Plugin_Handled;
		}
	} 
	else 
	{
		PrintToChat(client, "%s%s %sPlugin is currently disabled.", CTAG, TAG, CERROR);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
			LogToFile(LOGPATH, "%s %N attempted a Steam name reset but plugin is disabled.", LOGTAG, client);
		}	
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public void OnClientPutInServer(int client)
{
	if (GetConVarBool(changename_help))
	{
		char hbuffer[128];
		PrintToChat(client, "%s%s %sThis server allows name changes. Type %s!nhelp %sfor more information.", CTAG, TAG, CUSAGE, CLIME, CUSAGE);
		PrintToChat(client, hbuffer);
	}
	
	char PlayerName[64];
	
	if(!GetClientName (client, PlayerName, 64))
	{
		return;			
	}
	
	//NameCheck(PlayerName, client); //Whoops, leave it off.
}

/*public Action OnClientCommands(int client, char[] command, int argc)
{
	char text[32];
	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);
	
	CheckCommands(client, text);
	return Plugin_Continue;
}*/

public void OnClientAuthorized(int client)
{
	//Let us grab the SteamID and the name of the connecting players and save them
	
	char id[32], name[MAX_NAME_LENGTH];
	GetClientAuthId(client, AuthId_Steam2, id, sizeof(id));
	GetClientName(client, name, sizeof(name));
	g_names.SetString(id, name);
	if (GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s SetString has been executed successfully on %s.", LOGTAG, name);
	}
}

public Action Command_NameBan(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("[NAME] This command can only be used in-game.");
		return Plugin_Handled;
	}
	if (args < 1)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_name_ban <name to ban (NO SPACES)>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	if (args > 1)
	{
		PrintToChat(client, "%s%s %sOnly use one word with no spaces.", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char arg1[32];
	
	GetCmdArgString(arg1, sizeof(arg1));
	
	StripQuotes(arg1);
	TrimString(arg1);
	
	if (args == 1)
	{
		Handle nfile = OpenFile(fileName, "a+");
		for (int i = 0; i < lines; i++)
		{
			if (StrContains(arg1, BadNames[i], false) != -1)
			{
				PrintToChat(client, "%s%s %sThis name is already banned.", CTAG, TAG, CUSAGE);
				return Plugin_Handled;
			}
		}
		WriteFileLine(nfile, arg1);
		PrintToChat(client, "%s%s %sThis name has been added to the banned names list.", CTAG, TAG, CUSAGE);
		parseList_Name(false);
		CloseHandle(nfile);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s has been banned from being used in names.", LOGTAG, arg1);
		}
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action Command_SteamidBan(int client, int args)
{
	if (client == 0)
	{
		PrintToServer("[NAME] This command can only be used in-game.");
		return Plugin_Handled;
	}
	
	if (args < 1)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_name_banid <SteamID to ban>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char arg1[32];
	
	GetCmdArgString(arg1, sizeof(arg1));
	
	StripQuotes(arg1);
	TrimString(arg1);
	
	if(StrContains(arg1, "STEAM_", false) == -1)
	{
		PrintToChat(client, "%s%s %sThis is not a Steam 2 ID (STEAM_0:X:XXXX).", CTAG, TAG, CUSAGE);
		return Plugin_Handled;
	}
	
	for (int i = 0; i < bannedlines; i++)
	{
		if (StrContains(arg1, bannedsteamids[i], false) != -1)
		{
			PrintToChat(client, "%s%s %sThis SteamID is already banned.", CTAG, TAG, CUSAGE);
			return Plugin_Handled;
		}
	}
	
	Handle nfile = OpenFile(bannedidfile, "a+");
	WriteFileLine(nfile, arg1);
	PrintToChat(client, "%s%s %s%s %shas been added to the banned SteamIDs list.", CTAG, TAG, CPLAYER, arg1, CUSAGE);
	parseList_id(false);
	CloseHandle(nfile);
	if (GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s %s has been banned from changing names.", LOGTAG, arg1);
	}
	
	return Plugin_Handled;
}

public Action Command_SteamidUnban(int client, int args)
{
	File nfile = OpenFile(bannedidfile, "a+");
	
	if (nfile == null)
	{
		LogError("%s Could not open banned_id.ini", TAG);
		PrintToChat(client, "%s%s %sCould not open banned_id.ini", CTAG, TAG, CERROR);
	}
	
	if (client == 0)
	{
		PrintToServer("[NAME] This command can only be used in-game.");
		return Plugin_Handled;
	}
	
	if (args == 0)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_name_unbanid <SteamID to unban (NO SPACES)>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char arg1[32], arg2[32];
	
	GetCmdArgString(arg2, sizeof(arg2));
	
	StripQuotes(arg2);
	TrimString(arg2);
	
	bool found = false;
	ArrayList fileArray = CreateArray(32);
	
	while(!nfile.EndOfFile() && nfile.ReadLine(arg1, sizeof(arg1)))
	{
		if (strlen(arg1) < 1 || IsCharSpace(arg1[0])) continue;
		ReplaceString(arg1, sizeof(arg1), "\n", "", false); 
		if(!StrEqual(arg1, arg2, false))
		{
			fileArray.PushString(arg1);
		}
		else
		{
			found = true;
		}
	}
	
	delete nfile;
	
	if (found)
	{
		DeleteFile(bannedidfile);
		File newFile = OpenFile(bannedidfile, "a+");
		
		if (newFile == null)
		{
			LogError("%s Could not open banned_id.ini", TAG);
			PrintToChat(client, "%s%s %sCould not open banned_id.ini", CTAG, TAG, CERROR);
			return Plugin_Handled;
		}
		
		PrintToChat(client, "%s%s %s%s %shas been removed from the banned SteamIDs list.", CTAG, TAG, CPLAYER, arg2, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s removed from banned SteamIDs list.", TAG, arg2);
		}

		for (int i = 0; i < GetArraySize(fileArray); i++)
		{
			char writeLine[32];
			fileArray.GetString(i, writeLine, sizeof(writeLine));
			newFile.WriteLine(writeLine);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH,"%s %s added to the list.", TAG, writeLine);
			}
		}
		
		delete newFile;
		delete fileArray;
		parseList_id(false);
		return Plugin_Handled;
	}
	else
	{
		PrintToChat(client, "%s%s %sThis SteamID could not be found.", CTAG, TAG, CUSAGE);
		return Plugin_Handled;
	}
}

public Action Command_NameUnban(int client, int args)
{
	File nfile = OpenFile(fileName, "a+");
	
	if (nfile == null)
	{
		LogError("%s Could not open banned_names.ini", TAG);
		PrintToChat(client, "%s%s %sCould not open banned_names.ini", CTAG, TAG, CERROR);
	}
	
	if (args == 0)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_name_unban <name to unban (NO SPACES)>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char arg1[32], arg2[32];
	
	GetCmdArgString(arg2, sizeof(arg2));
	
	StripQuotes(arg2);
	TrimString(arg2);
	
	bool found = false;
	ArrayList fileArray = CreateArray(32);
	
	while(!nfile.EndOfFile() && nfile.ReadLine(arg1, sizeof(arg1)))
	{
		if (strlen(arg1) < 1 || IsCharSpace(arg1[0])) continue;
		ReplaceString(arg1, sizeof(arg1), "\n", "", false); 
		if(!StrEqual(arg1, arg2, false))
		{
			fileArray.PushString(arg1);
		}
		else
		{
			found = true;
		}
	}
	
	delete nfile;
	
	if (found)
	{
		DeleteFile(fileName);
		File newFile = OpenFile(fileName, "a+");
		
		if (newFile == null)
		{
			LogError("%s Could not open banned_names.ini", TAG);
			PrintToChat(client, "%s%s %sCould not open banned_names.ini", CTAG, TAG, CERROR);
			return Plugin_Handled;
		}
		
		PrintToChat(client, "%s%s %s%s %shas been removed from the banned name list.", CTAG, TAG, CPLAYER, arg2, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH,"%s %s removed from banned names list.", TAG, arg2);
		}
		
		for (int i = 0; i < GetArraySize(fileArray); i++)
		{
			char writeLine[32];
			fileArray.GetString(i, writeLine, sizeof(writeLine));
			newFile.WriteLine(writeLine);
			if (GetConVarBool(changename_debug))
			{
			LogToFile(LOGPATH,"%s %s removed from banned names list.", TAG, arg2);
			}
		}
		
		delete newFile;
		delete fileArray;
		parseList_Name(false);
		return Plugin_Handled;
	}
	else
	{
		PrintToChat(client, "%s%s %sThe name could not be found.", CTAG, TAG, CUSAGE);
		return Plugin_Handled;
	}
}
public Action Command_FilesRefresh(int client, int args)
{
	if (!client)
	{
		PrintToServer("%s This command can only be used in-game", TAG);
		return Plugin_Handled;
	}
	PrintToChat(client, "%s%s %sFiles rebuilt.", CTAG, TAG, CUSAGE);
	parseList_Name(true, client);
	parseList_id(true, client);
	OnMapStart();
	return Plugin_Handled;
}

public Action Command_Credits(int client, int args)
{
	if (!args || args > 0)
	{
		PrintToChat(client, "%s%s %s\"Set My Name\" %screated by %sPeter Brev. %sSpecial thanks to %sharper%s, %seyal282 %sand %sGrey83%s.", CTAG, TAG, CPLAYER, CUSAGE, CPLAYER, CUSAGE, CPLAYER, CUSAGE, CPLAYER, CUSAGE, CPLAYER, CUSAGE);
	}
	return Plugin_Handled;
}

public Action Command_Hname(int client, int args)
{
	if (args == 0)
	{
		PrintToChat(client, "%s%s %sPlease see the console for available commands.", CTAG, TAG, CUSAGE);
		PrintToConsole(client, "%s Available commands are:\nsm_name <new name> || Leave blank - Change your name or if no name is specified, it will revert to the name you had when joining\nsm_oname <#userid|name> - Shows the join name of a user\nsm_sname <#userid|name> - Shows the Steam name of a user\n!srname - Reset your name to your Steam name (this is a chat only command and cannot be used in your console)\nNOTE: Not all commands may be available. It is up to the server operator to decide what you have access to", TAG);
	}
	return Plugin_Handled;
}

public Action Command_Rename(int client, int args)
{
	if (args < 2)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_rename <#userid|name> <new name>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char arg[MAX_NAME_LENGTH], arg2[MAX_NAME_LENGTH]; 
	GetCmdArg(1, arg, sizeof(arg));
	
	if (args > 1)
	{
		GetCmdArg(2, arg2, sizeof(arg2));
	}
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_TARGET_NONE,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
			
		for (int i = 0; i < target_count; i++)
		{
			if (target_count > 1)
			{
				PrintToChat(client, "%s%s %sMore than one player cannot be renamed at a time.", CTAG, TAG, CUSAGE);
				return Plugin_Handled;
			}
			PrintToChatAll("%s%s %s%s %shas been renamed by an admin to %s%s%s.", CTAG, TAG, CPLAYER, target_name, CUSAGE, CPLAYER, arg2, CUSAGE);
			Format(g_targetnewname[target_list[i]], MAX_NAME_LENGTH, "%s", arg2);
			RenamePlayer(target_list[i]);
			
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %s has been renamed by %s to %s.", LOGTAG, target_name, client, arg2);
			}
		}
	}
	else
	{
		ReplyToTargetError(client, target_count);
	}
	
	return Plugin_Handled;
}

void RenamePlayer(int target)
{	
	SetClientName(target, g_targetnewname[target]);
	g_targetnewname[target][0] = '\0';
	
	char buffer[32];
	GetClientAuthId(target, AuthId_Steam2, buffer, sizeof(buffer));
	
	Handle nfile = OpenFile(adminrenamedfile, "a+");
	for (int i = 0; i < adminrenamedlines; i++)
	{
		if (StrContains(buffer, adminrenamedid[i], false) != -1)
		{
			return;
		}
	}
	WriteFileLine(nfile, buffer);

	int timeleft = GetConVarInt(changename_adminrename_cooldown);
	int mins, secs;
	if (timeleft > 0)
	{
		mins = timeleft / 60;
		secs = timeleft % 60;
		PrintToChat(target, "%s%s %sAn admin has renamed you. You have been temporarily banned from changing names for %s%d:%02d%s.", CTAG, TAG, CUSAGE, CPLAYER, mins, secs, CUSAGE);
		CheckTimer(target);
	}

	Handle DP = CreateDataPack();
	WritePackString(DP, buffer);
	WritePackCell(DP, target);
	CreateTimer(GetConVarFloat(changename_adminrename_cooldown), name_temp_ban, DP);

	CloseHandle(nfile);
	OnMapStart();
	if (GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s %s temporarily banned from changing names.", LOGTAG, target);
	}
	return;
		
}

public Action name_temp_ban(Handle timer, any DP)
{
		ResetPack(DP);
		
		char buffer[32];
		
		ReadPackString(DP, buffer, 32);

		CloseHandle(DP);
		
		PrintToServer("Value of buffer is %s", buffer);
		ArrayList fileArray = CreateArray(32);
		DeleteFile(adminrenamedfile);
		File newFile = OpenFile(adminrenamedfile, "a+");
		
		if (newFile == null)
		{
			LogError("%s Could not open admin_renamed_temp.ini", TAG);
			PrintToServer("%s Could not open admin_renamed_temp.ini", TAG);
			return Plugin_Handled;
		}
		
		PrintToServer("%s %s has been removed from the temporary banned name list.", TAG, buffer);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH,"%s %s removed from temporary banned names list.", TAG, buffer);
		}
		
		for (int i = 0; i < GetArraySize(fileArray); i++)
		{
			char writeLine[32];
			fileArray.GetString(i, writeLine, sizeof(writeLine));
			newFile.WriteLine(writeLine);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH,"%s %s removed from temporary banned names list.", TAG, buffer);
			}
		}
		delete newFile;
		delete fileArray;
		OnMapStart();
		return Plugin_Handled;	
	//PrintToChat(target, "%s%s %sThis name has been added to the banned names list.", CTAG, TAG, CUSAGE);
}

public Action Command_Oname(int client, int args)
{	
	
	//Check whether the plugin is enabled
	if (GetConVarBool(changename_enable_global))
	{
		if (GetConVarBool(originalname_enable))
		{

		} else
		{
			if (client == 0)
			{
				PrintToServer("%s Fetching original names has been disabled.", TAG);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Fetching original disabled due to ConVar \"sm_oname\" being set to 0.", LOGTAG);
					LogToFile(LOGPATH, "%s %N attempted to fetch an original name but ability is disabled.", LOGTAG, client);
				}
				return Plugin_Handled;
			} else {
				ReplyToCommand(client, "%s%s %sFetching original names has been disabled by an administrator.", CTAG, TAG, CERROR);
				return Plugin_Handled;
			}
		}
	} else 
	{
		if (client == 0)
		{
			PrintToServer("%s This plugin is currently disabled.", TAG);
			if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
					LogToFile(LOGPATH, "%s %N attempted to fetch an original name but plugin is disabled.", LOGTAG, client);
				}
			return Plugin_Handled;
		} else {
			ReplyToCommand(client, "%s%s %sThis plugin is currently disabled.", CTAG, TAG, CERROR);
			if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
					LogToFile(LOGPATH, "%s %N attempted to fetch an original name but plugin is disabled.", LOGTAG, client);
				}			
			return Plugin_Handled;
		}
	}
	//Just provide the command usage
	if (args < 1)
	{
		//Oname usage
		PrintToChat(client, "%s%s %sUsage: %ssm_oname <#userid|name>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char arg1[64];
	
	GetCmdArg(1, arg1, sizeof(arg1));
	
	int Target = FindTarget(client, arg1, true, false);
	
	if (Target == -1)
	{
		return Plugin_Handled; //If the client is not found, go ahead and return an error
	}
	
	char targetname[MAX_TARGET_LENGTH], buffer[MAX_NAME_LENGTH], id[32];
	
	GetClientAuthId(Target, AuthId_Steam2, id, sizeof(id));
	g_names.GetString(id, buffer, sizeof(buffer));
	GetClientName(Target, targetname, sizeof(targetname));
	
	if(strcmp(targetname, buffer))//We are now going to check whether the name == Original name upon connection
	{
		//Show orginal name if name was changed
		PrintToChat(client, "%s%s %sJoin name of %s%s %sis %s%s%s.", CTAG, TAG, CUSAGE, CPLAYER, targetname, CUSAGE, CPLAYER, buffer, CUSAGE);
		if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s Showing join name of %s (%s).", LOGTAG, targetname, buffer);
				LogToFile(LOGPATH, "%s %N executed sm_oname on %s (Join name: %s).", LOGTAG, client, targetname, buffer);
			}
	} else {
		//Name was not changed, then it must be their original name
		PrintToChat(client, "%s%s %s%s %sis the name they had when joining the server.", CTAG, TAG, CPLAYER, targetname, CUSAGE);
		if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %s is the name they had when they joined the server.", LOGTAG, targetname);
				LogToFile(LOGPATH, "%s %N executed sm_oname on %s but is their original name.", LOGTAG, client, targetname);
			}
	}
	return Plugin_Handled;	
}
void CheckTimer(int client)
{
	
	int iNow = GetTime(), iCooldown = GetConVarInt(changename_adminrename_cooldown);
	
	if(iCooldown > 0)
	{
		int iTimeLeft = g_iLastUsed[client] + iCooldown - iNow;
		int mins, secs;
		if (iTimeLeft > 0)
		{
			mins = iTimeLeft / 60;
			secs = iTimeLeft % 60;
			//char timeleftbuffer[128];
			PrintToChat(client, "%s%s %sAn admin recently renamed you. You will only be able to change your name in %s%d:%02d%s.", CTAG, TAG, CUSAGE, CPLAYER, mins, secs, CUSAGE);
			return;
		}
	}
			
	g_iLastUsed[client] = iNow;		
	
}
public Action Command_Name(int client, int args)
{	
	gB_HideNameChange = true;
	
	//Check whether the plugin is enabled
	if (GetConVarBool(changename_enable_global))
	{
		if (GetConVarBool(changename_enable))
		{

		} else
		{
			if (client == 0)
			{
				PrintToServer("%s Name changing has been disabled by an administrator.", TAG);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Name change disabled due to ConVar \"sm_cname_enable\" being set to 0.", LOGTAG);
					LogToFile(LOGPATH, "%s %N attempted a name change but ability is disabled.", LOGTAG, client);
				}
				return Plugin_Handled;
			} else {
				ReplyToCommand(client, "%s%s %sName changing has been disabled by an administrator.", CTAG, TAG, CERROR);
				return Plugin_Handled;
			}
		}
	} else 
	{
		if (client == 0)
		{
			PrintToServer("%s This plugin is currently disabled.", TAG);
			if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
					LogToFile(LOGPATH, "%s %N attempted a name change but plugin is disabled.", LOGTAG, client);
				}
			return Plugin_Handled;
		} else 
		{
			ReplyToCommand(client, "%s%s %sThis plugin is currently disabled.", CTAG, TAG, CERROR);
			return Plugin_Handled;
		}
	}
	
	//Let us just make sure to let the server operators know this is an in-game only command
	if (client == 0)
	{
		PrintToServer("%s This command can only be used in-game.", TAG);	
		return Plugin_Handled;
	}

	//With the saved player information, let us prepare the reset name stage
	
	AdminId playerAdmin = GetUserAdmin(client);
	
	if (args == 0)
	{		
		char id[32], buffer[MAX_NAME_LENGTH], currentname[MAX_NAME_LENGTH];
		
		GetClientAuthId(client, AuthId_Steam2, id, sizeof(id));
		
		g_names.GetString(id, buffer, sizeof(buffer));
		
		GetClientName(client, currentname, sizeof(currentname));
				
		if(strcmp(buffer, currentname, false))
		{
			if (GetConVarBool(changename_checkbadnames))
			{	
				if(!GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
				{
					for (int x = 0; x < lines; x++)
						{
						if (StrContains(buffer, BadNames[x], false) != -1)
						{
							char bantime = GetConVarInt(changename_bantime);
							
							if (bantime == -2)
							{
								PrintToChat(client, "%s%s %sYou cannot restore your name, because it is banned.", CTAG, TAG, CUSAGE);

								if (GetConVarBool(changename_debug))
								{
									LogToFile(LOGPATH, "%s %s attempted to change their name to a banned name.", LOGTAG, client);
								}
								return Plugin_Handled;
							}
						}				
					}
				}
			}
			
			if(GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
			{
				for (int z = 0; z < adminrenamedlines; z++)
				{					
					if (StrContains(id, adminrenamedid[z], false) != -1)
					{
						CheckTimer(client);
						if (GetConVarBool(changename_debug))
						{
							LogToFile(LOGPATH, "%s %s attempted to change their name, but they have been temporarily suspended from doing so following an admin sm_rename usage.", LOGTAG, client);
						}
						return Plugin_Handled;
					}
				}
			}
			
			int iNow = GetTime(), iCooldown = GetConVarInt(changename_cooldown);
	
			if(iCooldown > 0)
			{
				int iTimeLeft = g_iLastUsed[client] + iCooldown - iNow;
				int mins, secs;
				if (iTimeLeft > 0)
				{
					mins = iTimeLeft / 60;
					secs = iTimeLeft % 60;
					//char timeleftbuffer[128];
					PrintToChat(client, "%s%s %sYou must wait %s%d:%02d %sbefore changing your name again.", CTAG, TAG, CUSAGE, CPLAYER, mins, secs, CUSAGE);
					return Plugin_Handled;
				}
			}
			
			g_iLastUsed[client] = iNow;	
			
			SetClientName(client, buffer);
			
			//He reset his name
			PrintToChatAll("%s%s %s%s %shas reset their name to %s%s.", CTAG, TAG, CPLAYER, currentname, CUSAGE, CPLAYER, buffer);
			if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Player %s has reset their name to %s", LOGTAG, currentname, buffer);
				}
		}
		else
		{
			//Or the name is already set to original name
			PrintToChat(client, "%s%s %sYour name is already set to %s%s%s.", CTAG, TAG, CUSAGE, CPLAYER, currentname, CUSAGE);
			if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Player %s has not changed their name from their original one (name on connection) but has still attempted to reset their name to the one they had on server connection.", LOGTAG, currentname);
				}
		}
		return Plugin_Handled;
	}
	
	if(args > 0)
	{ 
		char sName[MAX_NAME_LENGTH], currentname[MAX_NAME_LENGTH], steamid[32];
		
		GetClientName(client, currentname, sizeof(currentname));
		
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		
		GetCmdArgString(sName, sizeof(sName));
		
		/*if (StrContains(sName, "@", false) == -1 || StrContains(sName, "/", false) == -1)
		{
			PrintToChat(client, "%s%s %sYou have used an illegal character.", CTAG, TAG, CUSAGE);
			return Plugin_Handled;
		}*/
		
		if(strcmp(sName, currentname))
		{
			if (GetConVarBool(changename_checkbadnames))
			{	
				if(!GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
				{
					for (int i = 0; i < lines; i++)
					{
						if (StrContains(sName, BadNames[i], false) != -1)
						{
							char bantime = GetConVarInt(changename_bantime);
							
							if (bantime == -2)
							{
								PrintToChat(client, "%s%s %sThis name is banned from being used.", CTAG, TAG, CUSAGE);

								if (GetConVarBool(changename_debug))
								{
									LogToFile(LOGPATH, "%s %s attempted to change their name to a banned name.", LOGTAG, client);
								}
								return Plugin_Handled;
							}
						}				
						
					}
				}
			}
			if(!GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
			{
				for (int y = 0; y < bannedlines; y++)
				{				
					if (StrContains(steamid, bannedsteamids[y], false) != -1)
					{
						char bantime = GetConVarInt(changename_bantime);
						if (GetConVarBool(changename_checkbannedids))
						{					
							if (bantime == -2)
							{
								PrintToChat(client, "%s%s %sYou cannot change your name due to an active name ban.", CTAG, TAG, CERROR);
								if (GetConVarBool(changename_debug))
								{
									LogToFile(LOGPATH, "%s %s attempted to change their name, but their Steam ID is banned from doing so.", LOGTAG, client);
								}
								return Plugin_Handled;
							}
						}
					}
				}
			}
			
			int iNow = GetTime(), iCooldown = GetConVarInt(changename_cooldown);
	
			if(iCooldown > 0)
			{
				int iTimeLeft = g_iLastUsed[client] + iCooldown - iNow;
				int mins, secs;
				if (iTimeLeft > 0)
				{
					mins = iTimeLeft / 60;
					secs = iTimeLeft % 60;
					//char timeleftbuffer[128];
					PrintToChat(client, "%s%s %sYou must wait %s%d:%02d %sbefore changing your name again.", CTAG, TAG, CUSAGE, CPLAYER, mins, secs, CUSAGE);
					return Plugin_Handled;
				}
			}
			
			g_iLastUsed[client] = iNow;	
			
			//He changed his name
			Handle DP = CreateDataPack();
		
			RequestFrame(TwoTotalFrames, DP);
			WritePackCell(DP, GetClientUserId(client));
			WritePackString(DP, sName);
		}
		else
		{
			//Name already set to the one he wants to set it to?
			PrintToChat(client, "%s%s %sYour name is already set to %s%s%s.", CTAG, TAG, CUSAGE, CPLAYER, currentname, CUSAGE);
			if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s %s has initiated an sm_name usage using a name that was already identical to the one they have.", LOGTAG, currentname);
				}
		}
				
	}
	
	return Plugin_Handled;
}

void TwoTotalFrames (Handle DP)
{
	RequestFrame (ChangeName, DP);
}

void ChangeName (Handle DP)
{
	ResetPack(DP);
	
	int client = GetClientOfUserId(ReadPackCell(DP));
	
	if(client <= 0 || client > MaxClients)
		return;
		
	else if(!IsClientInGame(client))
		return;
	
	char currentname[MAX_NAME_LENGTH];
	GetClientName(client, currentname, sizeof(currentname));
	char NewName[64];
	ReadPackString(DP, NewName, sizeof(NewName));
	CloseHandle(DP);
	bChanging[client] = true;
	SetClientInfo(client, "name", NewName);
	PrintToChatAll("%s%s %s%s %shas changed their name to %s%s%s.", CTAG, TAG, CPLAYER, currentname, CUSAGE, CPLAYER, NewName, CUSAGE);
	if (GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s %s has changed their name to %s.", LOGTAG, currentname, NewName);
	}
	return;
}
	
public Action Command_Sname(int client, int args)
{
	if (GetConVarBool(changename_enable_global))
	{
		if (GetConVarBool(steamname_enable))
		{

		} else
		{
			if (client == 0)
			{
				PrintToServer("%s Fetching Steam names has been disabled by an administrator.", TAG);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Fetching Steam name disabled due to ConVar \"sm_sname_enable\" being set to 0.", LOGTAG);
					LogToFile(LOGPATH, "%s %N attempted to fetch a Steam name but ability is disabled.", LOGTAG, client);
				}
				return Plugin_Handled;
			} else {
				ReplyToCommand(client, "%s%s %sFetching Steam names has been disabled by an administrator.", CTAG, TAG, CERROR);
				return Plugin_Handled;
			}
		}
	} else 
	{
		if (client == 0)
		{
			PrintToServer("%s This plugin is currently disabled.", TAG);
			if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
					LogToFile(LOGPATH, "%s %N attempted to fetch a Steam name but plugin is disabled.", LOGTAG, client);
				}
			return Plugin_Handled;
		} else {
			ReplyToCommand(client, "%s%s %sThis plugin is currently disabled.", CTAG, TAG, CERROR);
			return Plugin_Handled;
		}
	}

	if (args < 1)
	{
		PrintToChat(client, "%s%s %sUsage: %ssm_sname <#userid|name>", CTAG, TAG, CUSAGE, CLIME);
		return Plugin_Handled;
	}
	
	char targetarg[MAX_NAME_LENGTH];
	GetCmdArgString(targetarg, sizeof(targetarg));
	
	char target_name[MAX_TARGET_LENGTH];
	int target_list[MAXPLAYERS], target_count;
	bool tn_is_ml;
	
	int targetclient;
	
	if ((target_count = ProcessTargetString(
			targetarg,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_NO_IMMUNITY,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{		
		for (int i = 0; i < target_count; i++)
		{
			targetclient = target_list[i];
						
			QueryClientConVar(targetclient, "name", OnSteamNameQueried, GetClientUserId(client));	
		}
	}
	else
	{
		ReplyToTargetError(client, target_count);
	}
	return Plugin_Handled;
	
}

public void OnSteamNameQueried(QueryCookie cookie, int targetclient, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue, any UserId)
{
	int client = GetClientOfUserId(UserId);
	if (result != ConVarQuery_Okay)
	{
		PrintToChat(client, "%s%s %sError: Couldn't retrieve %s%N%s's Steam name.", CTAG, TAG, CERROR, CPLAYER, targetclient, CERROR);
		if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s An error occured during query.", LOGTAG);
			}
		return;
	}	
	
	if (client <= 0 || client > MaxClients)
		return;
		
	else if (!IsClientInGame(client))
		return;
	
	PrintToChat(client, "%s%s %s%N%s's Steam name is %s%s.", CTAG, TAG, CPLAYER, targetclient, CUSAGE, CPLAYER, cvarValue);
	if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Steam name queried.", LOGTAG);
		}
}

public void ChangeNameToSteamName(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	char steamid[32];
	char name[MAX_NAME_LENGTH];
	
	GetClientName(client, name, sizeof(name));	
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
        return;

	if (result != ConVarQuery_Okay)
    {
        PrintToChat(client, "%s%s %sCould not retrieve your Steam name.", CTAG, TAG, CERROR);
        if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s's Steam name not retrieved.", LOGTAG, client);
		}
        return;
    }
	
	AdminId playerAdmin = GetUserAdmin(client);
	
	if(!GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
	{	
		for (int i = 0; i < lines; i++)
	    {
	        if (StrContains(cvarValue, BadNames[i], false) != -1)
	        {
	            int bantime = GetConVarInt(changename_bantime);
	                
	            if (bantime == -2) 
	            {
					PrintToChat(client, "%s%s %sYou cannot use your Steam name, because it is banned.", CTAG, TAG, CUSAGE);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s attempted to reset their name to their Steam name, but it is part of the banned names list.", LOGTAG, client);
					}
	            }
	            
	            // name is naughty so we do not proceed further.
	            return;
	        }
	    }
		
		for (int y = 0; y < bannedlines; y++)
		{
			if (StrContains(steamid, bannedsteamids[y], false) != -1)
			{
				char bantime = GetConVarInt(changename_bantime);
										
				if (bantime == -2)
				{
					PrintToChat(client, "%s%s %sYou cannot change your name due to an active name ban.", CTAG, TAG, CUSAGE);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s attempted to reset their name, but their Steam ID is banned from doing so.", LOGTAG, client);
					}
					return;
				}
			}
		}
	}
    
    // steam name has passed the naughty check, now we can change it.
	if (!strcmp(name, cvarValue))
	{
		PrintToChat(client, "%s%s %sYour name is already your Steam name.", CTAG, TAG, CUSAGE);
		return;
	}
	else
	{
		int iNow = GetTime(), iCooldown = GetConVarInt(changename_cooldown);
	
		if(iCooldown > 0)
		{
			int iTimeLeft = g_iLastUsed[client] + iCooldown - iNow;
			int mins, secs;
			if (iTimeLeft > 0)
			{
				mins = iTimeLeft / 60;
				secs = iTimeLeft % 60;
				//char timeleftbuffer[128];
				PrintToChat(client, "%s%s %sYou must wait %s%d:%02d %sbefore changing your name again.", CTAG, TAG, CUSAGE, CPLAYER, mins, secs, CUSAGE);
				return;
			}
		}
		g_iLastUsed[client] = iNow;
		
		SetClientInfo(client, "name", cvarValue);
		PrintToChatAll("%s%s %s%s %shas restored their Steam name: %s%s%s.", CTAG, TAG, CPLAYER, name, CUSAGE, CPLAYER, cvarValue, CUSAGE);
		PrintToChat(client, "%sYour Steam name may take a few seconds to show.", CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s restored their Steam name to %s.", LOGTAG, name, cvarValue);
		}
	}
    
    // as we have used a Plugin return above, must use one at the end to avoid compiler warning.
	return;
}

public void ChangeNameToSteamNameRenameDisabled(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	char name[MAX_NAME_LENGTH];
	
	GetClientName(client, name, sizeof(name));	
			
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return;

	if (result != ConVarQuery_Okay)
	{
		PrintToChat(client, "%s%s %sCould not retrieve your Steam name.", CTAG, TAG, CERROR);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s's Steam name not retrieved and restored. Changing names ability disabled.", LOGTAG, client);
		}
		return;
	}
	
	AdminId playerAdmin = GetUserAdmin(client);
	
	if(!GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
	{
		for (int i = 0; i < lines; i++)
		{
			if (StrContains(cvarValue, BadNames[i], false) != -1)
			{
				int bantime = GetConVarInt(changename_bantime);
	                
				if (bantime == -2) 
				{
					PrintToChat(client, "%s%s %sThe ability to change names has now been disabled. Your Steam name was not restored, because it is banned on this server.", CTAG, TAG, CUSAGE);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s's Steam name was not restored despite \"sm_cname_enable\" set to 0, because their Steam name is banned.", LOGTAG, client);
					}
				}
	            
				// name is naughty so we do not proceed further.
				return;
			}
		}
	}
    
    // steam name has passed the naughty check, now we can change it.
	if (!strcmp(name, cvarValue))
	{
		return;
	}
	else
	{
		SetClientInfo(client, "name", cvarValue);
		PrintToChat(client, "%s%s %sThe ability to change names has now been disabled. Restoring your Steam name...", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s's Steam name restored due to name changing ability being disabled.", LOGTAG, client);
		}
	}
    
	// as we have used a Plugin return above, must use one at the end to avoid compiler warning.
	return;
} 

public void ChangeNameToSteamNamePluginDisabled(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	char name[MAX_NAME_LENGTH];
	
	GetClientName(client, name, sizeof(name));	
			
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return;

	if (result != ConVarQuery_Okay)
	{
		PrintToChat(client, "%s%s %sThis plugin has now been disabled. However, your Steam name could not be retrieved and restored.", CTAG, TAG, CERROR);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s's Steam name not retrieved and restored. Plugin disabled.", LOGTAG, client);
		}
		return;
	}
	
	if (!strcmp(name, cvarValue))
	{
		return;
	}
	else
	{
		SetClientInfo(client, "name", cvarValue);
		PrintToChat(client, "%s%s %sThis plugin has now been disabled. Restoring your Steam name...", CTAG, TAG, CUSAGE);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s %s's Steam name restored due to plugin being disabled.", LOGTAG, client);
		}
	}
    
    // as we have used a Plugin return above, must use one at the end to avoid compiler warning.
	return;
} 

public void ChangeNameToSteamNameIdBanned(QueryCookie cookie, int client, ConVarQueryResult result, const char[] cvarName, const char[] cvarValue)
{
	char name[MAX_NAME_LENGTH];
	
	GetClientName(client, name, sizeof(name));	
			
	if (client < 1 || client > MaxClients || !IsClientInGame(client))
		return;
		
	AdminId playerAdmin = GetUserAdmin(client);
	
	if(!GetAdminFlag(playerAdmin, Admin_Generic, Access_Effective))
	{
		if (result != ConVarQuery_Okay)
		{
			PrintToChat(client, "%s%s %sAn active name ban has been detected. However, your Steam name could not be retrieved and restored.", CTAG, TAG, CERROR);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %s's Steam name not retrieved and restored. Active SteamID name ban.", LOGTAG, client);
			}
			return;
		}
		
		if (!strcmp(name, cvarValue))
		{
			return;
		}
		else
		{
			SetClientInfo(client, "name", cvarValue);
			PrintToChat(client, "%s%s %sAn active name ban has been detected. Restoring your Steam name...", CTAG, TAG, CUSAGE);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %s's Steam name restored due to SteamID name ban.", LOGTAG, client);
			}
		}
	}
    
    // as we have used a Plugin return above, must use one at the end to avoid compiler warning.
	return;
} 

public void OnConVarChanged_Debug(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{	
				if (x == 0)
				{
					PrintToServer("%s Debug mode has been enabled. Independant logs will be created in logs/NameLogs", LOGTAG);
					Debug_Path();
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					char xbuffer[128];
					Format(xbuffer, sizeof(xbuffer), "%s%s Debug mode has been enabled. Independant logs will be created in logs/NameLogs", CLOGTAG, LOGTAG);
					PrintToChat(x, xbuffer);
					if (GetConVarBool(changename_debug_snd))
					{
						EmitSoundToClient(x, g_SoundName_On);
					}
				}
			} 
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Debug mode has been disabled. Logging terminated.", LOGTAG);
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					char cbuffer[128];
					Format(cbuffer, sizeof(cbuffer), "%s%s Debug mode has been disabled. Logging terminated.", CLOGTAG, LOGTAG);
					PrintToChat(x, cbuffer);
					if (GetConVarBool(changename_debug_snd))
					{
						EmitSoundToClient(x, g_SoundName_Off);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_Global(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{	
				if (x == 0)
				{
					PrintToServer("%s Name plugin is now enabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Name plugin enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{	
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s Name plugin enabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			} 
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Name plugin is now disabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Name plugin disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x))
				{
					QueryClientConVar(x, "name", ChangeNameToSteamNamePluginDisabled);
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s Name plugin disabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
						QueryClientConVar(x, "name", ChangeNameToSteamNamePluginDisabled);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_Name(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{	
				if (x == 0)
				{
					PrintToServer("%s Name change ability is now enabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Name change ability enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{	
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s Name change enabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			} 
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Name change ability is now disabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Name change ability disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x))
				{
					QueryClientConVar(x, "name", ChangeNameToSteamNameRenameDisabled);
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s Name change ability disabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
						QueryClientConVar(x, "name", ChangeNameToSteamNameRenameDisabled);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_Oname(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{	
				if (x == 0)
				{
					PrintToServer("%s Fetching original names ability is now enabled..", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Fetching original names ability enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{	
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s Fetching original names enabled..", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			} 
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Fetching original names ability is now disabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Fetching original names ability disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s Fetching original names ability disabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_Sname(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{	
				if (x == 0)
				{
					PrintToServer("%s Fetching Steam names ability is now enabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Fetching Steam names ability enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{	
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s Fetching Steam names enabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			} 
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Fetching Steam names ability is now disabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Fetching Steam names ability disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s Fetching Steam names ability disabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_Snd(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{	
				if (x == 0)
				{
					PrintToServer("%s Debug sounds are now enabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Debug sounds enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{	
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s Debug sounds enabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			} 
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Debug sounds are now disabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Debug sounds disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s Debug sounds disabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_SndOn(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "\0") == 0)
			{	
				if (x == 0)
				{
					PrintToServer("%s No sound file was set for \"sm_name_snd_warn_on\"! Setting default value.", TAG);
					ResetConVar(changename_debug_snd_warn_off, false, false);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s No sound file was set for \"sm_name_snd_warn_on\"! Setting default value.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s No sound file was set for \"sm_name_snd_warn_on\"! Setting default value.", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_SndOff(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "\0") == 0)
			{	
				if (x == 0)
				{
					PrintToServer("%s No sound file was set for \"sm_name_snd_warn_off\"! Setting default value.", TAG);
					ResetConVar(changename_debug_snd_warn_off, false, false);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s No sound file was set for \"sm_name_snd_warn_off\"! Setting default value.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s No sound file was set for \"sm_name_snd_warn_off\"! Setting default value.", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_Srname(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{	
				if (x == 0)
				{
					PrintToServer("%s Steam name reset ability is now enabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Steam name reset ability is now enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{	
					if (GetConVarBool(changename_debug))
					{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s Steam name reset ability enabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
					}
				}
			} 
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Steam name reset ability is now disabled.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Steam name reset ability is now disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s Steam name reset ability disabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_NameCheck(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{	
				if (x == 0)
				{
					PrintToServer("%s Names will now be checked against banned_names.ini.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Checking for banned names enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x))
				{
					if (GetAdminFlag(GetUserAdmin(x), Admin_Root))
					{
						if (GetConVarBool(changename_debug))
						{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s Checking for banned names enabled. Reading banned_names.ini", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
						}
						return;
					}
					
					char playerName[64];
					GetClientName(x, playerName, sizeof(playerName));
					NameCheck(playerName, x);
				}
			} 
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s Names will no longer be checked against banned_names.ini.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Checking for banned names disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s No longer checking for banned names.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
					}
				}
			}
		}
	}
}

public void OnConVarChanged_IdCheck(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int x = 0; x <= MaxClients; x++)
	{
		if (strcmp(oldValue, newValue) != 0)
		{
			if (strcmp(newValue, "1") == 0)
			{	
				if (x == 0)
				{
					PrintToServer("%s SteamIDs will now be checked against banned_id.ini.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Checking for banned SteamIDs enabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x))
				{
					if (GetAdminFlag(GetUserAdmin(x), Admin_Root))
					{
						if (GetConVarBool(changename_debug))
						{
						char xbuffer[128];
						Format(xbuffer, sizeof(xbuffer), "%s%s Checking for banned SteamIDs enabled. Reading banned_id.ini", CLOGTAG, LOGTAG);
						PrintToChat(x, xbuffer);
						}
						return;
					}
					
					char playerId[64];
					char playerName[64];
					GetClientName(x, playerName, sizeof(playerName));
					GetClientAuthId(x, AuthId_Steam2, playerId, 64);
					for (int i = 0; i < bannedlines; i++)
					{
						if (StrContains(playerId, bannedsteamids[i], false) != -1)
						{
							QueryClientConVar(x, "name", ChangeNameToSteamNameIdBanned);
						}
					}
				}
			} 
			else if (strcmp(newValue, "0") == 0)
			{
				if (x == 0)
				{
					PrintToServer("%s SteamIDs will no longer be checked against banned_id.ini.", TAG);
					if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s Checking for banned SteamIDs disabled.", LOGTAG);
					}
				}
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s No longer checking for SteamIDs names.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
					}
				}
			}
		}
	}
}

public Action Hook_SayText2(UserMsg msg_id, any msg, const int[] players, int playersNum, bool reliable, bool init)
{
	if(!gB_HideNameChange)
	{
		return Plugin_Continue;
	}

	char sMessage[256];

	if(GetUserMessageType() == UM_Protobuf)
	{
		Protobuf pbmsg = msg;
		pbmsg.ReadString("msg_name", sMessage, 256);
	}

	else
	{
		BfRead bfmsg = msg;
		bfmsg.ReadByte();
		bfmsg.ReadByte();
		bfmsg.ReadString(sMessage, 24, false);
	}

	if(StrEqual(sMessage, CS_NAME_CHANGE_STRING) || StrEqual(sMessage, TF_NAME_CHANGE_STRING))
	{
		gB_HideNameChange = false;

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

/******************************
PLUGIN FUNCTIONS
******************************/
void Debug_Path() //Sets the debug log path
{
	//Setting up the directory for the log file
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/NameChanger");
	
	if(!DirExists(sPath))
	{
		CreateDirectory(sPath, 511);
	}
}

void ConVarCheck()
{
	CreateTimer(15.0, ConVarChecker_Callback, _, TIMER_REPEAT);
}

void parseList_Name(bool rebuild, int client = 0)
{
	char arg1[32];
	File hFile = OpenFile(fileName, "a+");
    
	if (hFile == INVALID_HANDLE)
	{
		PrintToServer("%s An error was encountered opening the file banned_names.ini", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s banned_names.ini could not be opened.", LOGTAG);
		}
		return;
	}

	while(!hFile.EndOfFile() && hFile.ReadLine(arg1, sizeof(arg1)))
	{
		TrimString(arg1);
		StripQuotes(arg1);

		if(strlen(arg1) < 1) continue;

		if(StrContains(arg1, "STEAM_", false) != -1)
		{
			g_bannednames.SetString(arg1, arg1, true);
		}
	}
	if (rebuild && client && GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s%s banned_names.ini rebuilt.", LOGTAG);
	}
	delete hFile;
}

void parseList_id(bool rebuild, int client = 0)
{
    char arg1[32];
    File nFile = OpenFile(bannedidfile, "a+");
    
    if (nFile == INVALID_HANDLE)
    {
   		PrintToServer("%s An error was encountered opening the file banned_id.ini", TAG);
   		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s banned_id.ini could not be opened.", LOGTAG);
		}
   		return;
  	}

    while(!nFile.EndOfFile() && nFile.ReadLine(arg1, sizeof(arg1)))
    {
        TrimString(arg1);
        StripQuotes(arg1);

        if(strlen(arg1) < 1) continue;

        if(StrContains(arg1, "STEAM_", false) != -1)
        {
            g_bannedids.SetString(arg1, arg1, true);
        }
    }
    if (rebuild && client && GetConVarBool(changename_debug))
	{
		LogToFile(LOGPATH, "%s banned_id.ini rebuilt.", LOGTAG);
	}
    delete nFile;
}
//PETER BREV, SIGNING OFF

/*************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
*****************************************************************!AND THE DREAM ENDS HERE!********************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************/

