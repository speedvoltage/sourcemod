/**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
******************************************************************!AND HERE BEGINS A DREAM!*******************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************/

/******************************
ROAD MAP
*******************************/

	/*TO DO IN VERSION 1.4.0.0:
	
	*sm_name_filter <name> -> Adds a name to the filter, preventing players from using it (will have a file to add names into)
	*sm_name_remove <name> -> Removes a name to the filter, allowing players to use it
	*sm_name_ban <#userid|name> -> Bans a player from using sm_name and revert their name to their default name they joined with (will have a file to add players into)
	*sm_name_unban <#userid|name> -> Unbans a player from using sm_name
	*Cookies -> Store their custom name in a cookie so that they do not have to type next time they join (Option to have the cookie deleted after a certain time)
	*Name history
	*Cooldown -> Prevent a player from changing their name for X seconds after a previous name change
	*Admin menu -> Include an entry for sm_name_ban and sm_name_unban
	*Warnings*/
	
	/*Should we?*/
	
	/*Use MySQL to store used names, let players save names for them to use again in the future?*/

/******************************
VERSION HISTORY
*******************************/

/***VERSION 1.3.0.0***/

	/*Changelog:
	
	1) New ConVars:
	
	//General ConVars
	
	[NEW] sm_name_enable 0/1 -> Controls whether the plugin should be enabled or disabled
	[NEW] sm_cname_enable 0/1 -> Controls whether players can change their name
	[NEW] sm_oname_enable 0/1 -> Controls whether players can check original name of players
	[NEW] sm_sname_enable 0/1 -> Controls whether players can check Steam name of players
	[NEW] sm_srname_enable 0/1 -> Controls whether players can reset to their Steam name
	
	A timer will check every 15 seconds if values for sm_cname_enable, sm_oname_enable and sm_sname_enable (and/or sm_name_enable) are set to 0. If they are, the plugin will automatically set values for sm_cname_enable, sm_oname_enable and sm_sname_enable to 1 and sm_name_enable to 0. This is hard-coded, though, and cannot be changed yet.
	
	//Technical ConVars
	[NEW] sm_name_debug 0/1 -> Toggles logging for debugging purposes (Only use this if you are experiencing weird issues)
	[NEW] sm_name_debug_snd 0/1 -> Sets whether to play a sound when debug mode is toggle on or off
	[NEW] sm_name_debug_snd_on <sound file> (starts from the "sound" folder and you do not need to include "sound/"; make sure you put forward slashes "/")
	[NEW] sm_name_debug_snd_off <sound file> (starts from the "sound" folder and you do not need to include "sound/"; make sure you put forward slashes "/")
	
	The debugger can be activated with sm_name_debug 0/1. Its purpose is to log every command executed by players in a file called NameChanger.log that you can find in sourcemod/logs/NameChanger folder. If you are in-game, those messages will appear in gray. To avoid your log folder from using too much space, the command sm_name_debug is set to turn off automatically when the map ends.
  
	2) Code revisited

	[REVISION] *sm_oname <#userid|name> now fetches the name upon connection to the server and stores until you reconnect
	[NEW] *sm_sname <#userid|name> is a new public command that will properly fetch the Steam name
	[NEW] *sm_srname will properly reset your name to your Steam name
  
	3) Translation files

	[NEW] New translations created.

	4) Customization

	[NEW] Plugin customization with name.plugin.cfg in sourcemod/cfg

	5) Other less important changes

	If you use the plugin in another game than Half-Life 2: Deathmatch, a warning will let you know that it is untested in other games.
	If you are using another name plugin, this plugin will halt and throw an error letting you know you cannot run two name plugins at once.*/
	

/***VERSION 1.2.0.0***/

	/*Changelog:
	
	Fixed an issue with sm_oname where only admins could use it and would report unknown command to regular players
	Blocked default name change messages shown by the game*/
	

/***VERSION 1.1.0.0***/

	/*Changelog:

	Added the base code author in the plugin's name
	The plugin now checks whether the name you are trying to input is identical to your current name
	Made name changes print to everyone (the default name change message from the engine is not blocked, but this is a simple fix)
	Added sm_oname <#userid|name> which will print the Steam name of the user you are targeting at*/


/***VERSION 1.0.0.0***/

	/*Initial release of plugin Set My Name*/

/******************************/

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
#define PLUGIN_VERSION							"1.4.0.1928" //Build number since 05/12/18
#define PLUGIN_DESCRIPTION						"Allows players to use a new name"
#define PLUGIN_URL								"https://peterbrev.info"

/*Plugin defines for messages*/
#define TAG									"[NAME]"
#define CTAG 									"\x07cc3300"
#define CUSAGE 								"\x0700ace6"
#define CERROR 								"\x07ff0000"
#define CLIME									"\x0700ff15"
#define CPLAYER								"\x07ffb200"

/*Cooldown for name changes*/
#define NAME_COOLDOWN	10.0

/*Logging*/
#define LOGTAG									"[NAME DEBUG]"
#define CLOGTAG								"\x078e8888"
#define LOGPATH								"addons/sourcemod/logs/NameChanger/NameChanger.log"

/*Sound*/
#define MAX_FILE_LEN							80

/*Boolean for the ability to change names*/
bool CanChangeName [MAXPLAYERS+1] = {true, ...};

/*Boolean for EventHook*/

bool EventsHook = false;

/******************************
PLUGIN STRINGMAPS
******************************/

StringMap g_names;

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


//Sound Handles
Handle changename_debug_snd;

Handle changename_debug_snd_warn_on = INVALID_HANDLE;
Handle changename_debug_snd_warn_off = INVALID_HANDLE;

/******************************
PLUGIN STRINGS
******************************/

char g_SoundName_On[MAX_FILE_LEN];
char g_SoundName_Off[MAX_FILE_LEN];

char BadNames[255][64];
char fileName[PLATFORM_MAX_PATH];
char lines;

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
	//I don't think this is needed anymore. Left in there, just in case.
	/***VERIFY THE ENGINE***/
	
	/*char game[128];
	GetGameFolderName(game, sizeof(game));

	EngineVersion engine = GetEngineVersion();

	if (StrEqual(game, "left4dead", false)
			|| StrEqual(game, "dystopia", false)
			|| StrEqual(game, "synergy", false)
			|| StrEqual(game, "left4dead2", false)
			|| StrEqual(game, "garrysmod", false)
			|| StrEqual(game, "swarm", false)
			|| StrEqual(game, "bms", false)
			|| StrEqual(game, "reactivedrop", false)
			|| StrEqual(game, "cstrike", false)
			|| StrEqual(game, "tf2", false)
			|| engine == Engine_Insurgency
			|| engine == Engine_DOI
			|| engine == Engine_DarkMessiah
			|| engine == Engine_EYE
			|| engine == Engine_DOTA
			|| engine == Engine_BloodyGoodTime
			|| engine == Engine_Unknown
			|| engine == Engine_Contagion)
			
	{
		PrintToServer("%s WARNING: This plugin is untested in games other than Half-Life 2: Deathmatch \n");
		PrintToServer("If this plugin is not working properly in your game, please report it to Peter \"speedvoltage\" Brev here: \n");
		PrintToServer("https://forums.alliedmods.net/showthread.php?p=2592819 \n");
	}*/
	
	/***STOP PLUGIN IF OTHER NAME PLUGIN IS FOUND***/
	
	if (FindPluginByFile("sm_name.smx") != null)
	{
		ThrowError("%s You are using a plugin from Eyal282 that delivers the same function. You cannot run both at once!", TAG);
		LogError("Attempt to load both \"sm_name.smx\" and \"name.smx\". This is invalid!");
	}
	
	//Technically, the following code is no longer required, becaused we're now waiting two frames before changing a name.
	/*if (FindPluginByFile("ChatRevamp.smx") != null || FindPluginByFile("simple-chatprocessor.smx") != null || FindPluginByFile("chat-processor.smx") != null)
	{
		ThrowError("%s WARNING: Your server is running a chat processor plugin. Because there is a minor conflict between it and \"Set My Name\", this plugin has been unloaded. Please wait for the author to completely fix the issue.", TAG);
		ServerCommand("sm plugins unload name.smx");
	}*/

	/***PRE-SETUP***/
	
	g_names = CreateTrie();
	
	//We want to hook player_changename in order to block the default message from showing
	
	bool exists = HookEventEx("player_changename", namechange_callback, EventHookMode_Pre);
	if (!exists)
	{
		SetFailState("Event player_changename does not exist. Unloading...");
	}
	
	//Finally, load the translations
	
	LoadTranslations("common.phrases");
	LoadTranslations("name.phrases");

	/***COMMANDS SETUP***/
	
	//Create a convar for plugin version & with the help of the handle, go ahead and put the proper version
	
	changename_version = CreateConVar("sm_name_version", PLUGIN_VERSION, "Plugin Version (DO NOT CHANGE)", FCVAR_NOTIFY|FCVAR_SPONLY|FCVAR_DEVELOPMENTONLY);
	
	SetConVarString(changename_version, PLUGIN_VERSION);
	
	//Create ConVars
	
	//General
	changename_help = CreateConVar("sm_name_help_enable", "1", "Controls whether the plugin should print a help message when clients join", 0, true, 0.0, true, 1.0);
	changename_enable_global = CreateConVar("sm_name_enable", "1", "Controls whether the plugin should be enabled or disabled", 0, true, 0.0, true, 1.0);
	changename_enable = CreateConVar("sm_cname_enable", "1", "Controls whether players can change their name", 0, true, 0.0, true, 1.0);
	originalname_enable = CreateConVar("sm_oname_enable", "1", "Controls whether players can check original name of players", 0, true, 0.0, true, 1.0);
	steamname_enable = CreateConVar("sm_sname_enable", "1", "Controls whether players can check Steam name of players", 0, true, 0.0, true, 1.0);
	changename_steamreset = CreateConVar("sm_srname_enable", "1", "Controls whether players can reset their name to their Steam name", 0, true, 0.0, true, 1.0);
	changename_bantime = CreateConVar("sm_nban_time", "-2", "Controls the length of the ban. Use \"-1\" to kick, \"-2\" to display a message to the player.");
	changename_banreason = CreateConVar("sm_nban_reason", "[AUTO-DISCONNECT] This name is inappropriate. Please change it.", "What message to display on kick/ban.");
	//AutoExecConfig(true, "plugin.badnamekickban");
	
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
	
	//Listners (We are using this for !srname (Steam Reset name) to go around a little bug with the engine. This is why we do not register a public command for it
	AddCommandListener(OnClientCommands, "say");
	AddCommandListener(OnClientCommands, "say_team");
	
	//Create the public commands
	RegConsoleCmd("sm_name", Command_Name, "sm_name <new name> (Leave blank to reset to join name or Steam name)");
	RegConsoleCmd("sm_oname", Command_Oname, "sm_oname <#userid|name> - Find the original name of a player upon connection");
	RegConsoleCmd("sm_sname", Command_Sname, "sm_sname <#userid|name> - Find the Steam name of a player");
	RegConsoleCmd("sm_nhelp", Command_Hname, "sm_name_help - Prints commands to the clients console");

	
	//Configs
	AutoExecConfig();
	
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

public void OnConfigsExecuted()
{
	GetConVarString(changename_debug_snd_warn_on, g_SoundName_On, MAX_FILE_LEN);
	GetConVarString(changename_debug_snd_warn_off, g_SoundName_Off, MAX_FILE_LEN);
	PrecacheSound(g_SoundName_On, true);	
	PrecacheSound(g_SoundName_Off, true);	
}

public Action ConVarChecker_Callback(Handle timer, any data)
{
	if (!GetConVarBool(changename_enable) && !GetConVarBool(originalname_enable) && !GetConVarBool(steamname_enable))
	{
		SetConVarFloat(changename_enable, 1.0, _, false);
		SetConVarFloat(originalname_enable, 1.0, _, false);
		SetConVarFloat(steamname_enable, 1.0, _, false);
		SetConVarFloat(changename_enable_global, 0.0, _, false);
		PrintToServer("%s ConVar \"sm_cname_enable\", \"sm_oname_enable\" and \"sm_sname_enable\" were set to 0. This is the same behavior as setting ConVar \"sm_name_enable\" to 0. All three ConVars were set to 1 and \"sm_name_enable\" was set to 0. Use 1 to enable the plugin again.", TAG);
		PrintToServer("%s This plugin is disabled. To turn it on, use \"sm_name_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Plugin is disabled due to ConVar \"sm_cname_enable\", \"sm_oname_enable\" and \"sm_sname_enable\" being turned off.", LOGTAG);
		}
	}	
}

public void OnMapStart()
{
	for (int i = 0; i < lines; i++)
	{
		BadNames[i] = "";
	}
	
	lines = 0;
	
	if (ReadConfig() && !EventsHook)
	{
		HookEvent("player_changename", checkName);
		EventsHook = true;
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
	} else if (!GetConVarBool(changename_enable) && !GetConVarBool(originalname_enable) && !GetConVarBool(steamname_enable))
	{
		SetConVarFloat(changename_enable, 1.0, _, false);
		SetConVarFloat(originalname_enable, 1.0, _, false);
		SetConVarFloat(steamname_enable, 1.0, _, false);
		SetConVarFloat(changename_enable_global, 0.0, _, false);
		PrintToServer("%s ConVar \"sm_cname_enable\", \"sm_oname_enable\" and \"sm_sname_enable\" were set to 0. This is the same behavior as setting ConVar \"sm_name_enable\" to 0. All three ConVars values were set to 1 and ConVar value \"sm_name_enable\" was set to 0. Use 1 to enable the plugin again.", TAG);
		PrintToServer("%s This plugin is disabled. To turn it on, use \"sm_name_enable 1\"", TAG);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Plugin is disabled due to ConVars values \"sm_cname_enable\", \"sm_oname_enable\" and \"sm_sname_enable\" being set to 0.", LOGTAG);
		}
	} else if (!GetConVarBool(changename_enable_global) && !GetConVarBool(changename_enable) && !GetConVarBool(originalname_enable) && !GetConVarBool(steamname_enable))
	{
		SetConVarFloat(changename_enable, 1.0, _, false);
		SetConVarFloat(originalname_enable, 1.0, _, false);
		SetConVarFloat(steamname_enable, 1.0, _, false);
		SetConVarFloat(changename_enable_global, 0.0, _, false);
		PrintToServer("%s All ConVars values were set to 0. ConVar \"sm_cname_enable\", \"sm_oname_enable\" and \"sm_sname_enable\" values were set to 0 and ConVar \"sm_name_enable\" was set to 1.", TAG);
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
	BuildPath(Path_SM, fileName, sizeof(fileName), "configs/banned_names.ini");
	Handle file = OpenFile(fileName, "rt");
	if (file == INVALID_HANDLE)
	{
		LogError("[NAME] Banned names file could not be opened.", fileName);
		return false;
	}
	
	if (file != INVALID_HANDLE)
	{
		PrintToServer("[NAME] Successfully loaded banned_names.ini", fileName);
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
	
	if(!GetClientName (client, PlayerName, 64))
	{
		return;			
	}
	
	NameCheck(PlayerName, client);
}

void NameCheck(char clientName[64], char player)
{
	char PlayerID = GetClientUserId(player);
	AdminId playerAdmin = GetUserAdmin(player);
	//char playerAdmin = GetUserAdmin(player);	
	//view_as<AdminId>(playerAdmin) = GetUserAdmin(player);
	
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
			
			if (bantime > -1)
			{
				ServerCommand("sm_ban #%i %i %s", PlayerID, bantime, reason);
			}
			if (bantime == -2)
			{
				PrintToChat(player, "[NAME] This name has been banned from being used.");
			}
				
			if (bantime == -1)
			{
				ServerCommand ("sm_kick #%i %s", PlayerID, reason);
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
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s Default player name change messages suppressed.", LOGTAG);
			}
			return Plugin_Continue;
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

public void CheckCommands(int client, char[] string)
{
	if (GetConVarBool(changename_enable_global))
	{
		if (GetConVarBool(changename_steamreset))
		{
			if (string[0] == '!' && string[1] == 's' && string[2] == 'r' && string[3] == 'n' && string[4] == 'a' && string[5] == 'm' && string[6] == 'e')
			{
				QueryClientConVar(client, "name", ChangeNameToSteamName);
				char snrbuffer[128], nnrbuffer[128];
				Format(snrbuffer, sizeof(snrbuffer), "%T", "SteamNameReset", LANG_SERVER, CTAG, TAG, CUSAGE);
				Format(nnrbuffer, sizeof(nnrbuffer), "%T", "SteamNoResetIf", LANG_SERVER, CUSAGE);
				PrintToChat(client, snrbuffer);
				PrintToChat(client, nnrbuffer);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s %N has attempted a Steam name reset.", LOGTAG, client);
				}
			}
		}
		else
		{
			char snrdbuffer[128];
			Format(snrdbuffer, sizeof(snrdbuffer), "%T", "SteamNameResetDisabled", LANG_SERVER, CTAG, TAG, CERROR);
			PrintToChat(client, snrdbuffer);
			if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s Steam name reset ability disabled.", LOGTAG);
				LogToFile(LOGPATH, "%s %N attempted a Steam name reset but ability is disabled.", LOGTAG, client);
			}
		}
	} 
	else 
	{
		char pbuffer[128];
		Format(pbuffer, sizeof(pbuffer), "%T", "PluginDisabled", LANG_SERVER, CTAG, TAG, CERROR);
		PrintToChat(client, pbuffer);
		if (GetConVarBool(changename_debug))
		{
			LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
			LogToFile(LOGPATH, "%s %N attempted a Steam name reset but plugin is disabled.", LOGTAG, client);
		}			
	}
}

public void OnClientPutInServer(int client)
{
	if (GetConVarBool(changename_help))
	{
		char hbuffer[128];
		Format(hbuffer, sizeof(hbuffer), "%T", "NameHelp", LANG_SERVER, CTAG, TAG, CUSAGE, CLIME, CUSAGE);
		PrintToChat(client, hbuffer);
	}
}

public Action OnClientCommands(int client, char[] command, int argc)
{
	char text[32];
	GetCmdArgString(text, sizeof(text));
	StripQuotes(text);
	
	CheckCommands(client, text);
	return Plugin_Continue;
}

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

public Action Command_Hname(int client, int args)
{
	if (args == 0)
	{
		char phbuffer[1024];
		Format(phbuffer, sizeof(phbuffer), "%T", "NameHelpConsole", LANG_SERVER, CTAG, TAG, CUSAGE);
		PrintToChat(client, phbuffer);
		PrintToConsole(client, "%s Available commands are:\nsm_name <new name> || Leave blank - Change your name or if no name is specified, it will revert to the name you had when joining\nsm_oname <#userid|name> - Shows the join name of a user\nsm_sname <#userid|name> - Shows the Steam name of a user\n!rsname - Reset your name to your Steam name (this is a chat only command and cannot be used in your console)\nNOTE: Not all commands may be available. It is up to the server operator to decide what you have access to", TAG);
	}
	return Plugin_Handled;
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
				char tbuffer[128];
				Format(tbuffer, sizeof(tbuffer), "%T", "OriginalNameFetchDisabled", LANG_SERVER, CTAG, TAG, CERROR);
				ReplyToCommand(client, tbuffer);
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
			char pbuffer[128];
			Format(pbuffer, sizeof(pbuffer), "%T", "PluginDisabled", LANG_SERVER, CTAG, TAG, CERROR);
			ReplyToCommand(client, pbuffer);
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
		ReplyToCommand(client, "%s%s %sUsage: %ssm_oname <#userid|name>", CTAG, TAG, CUSAGE, CLIME);
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
		char jbuffer[128];
		Format(jbuffer, sizeof(jbuffer), "%T", "JoinName", LANG_SERVER, CTAG, TAG, CUSAGE, CPLAYER, targetname, CUSAGE, CPLAYER, buffer, CUSAGE);
		ReplyToCommand(client, jbuffer);
		if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s Showing join name of %s (%s).", LOGTAG, targetname, buffer);
				LogToFile(LOGPATH, "%s %N executed sm_oname on %s (Join name: %s).", LOGTAG, client, targetname, buffer);
			}
	} else {
		//Name was not changed, then it must be their original name
		char djnbuffer[128];
		Format(djnbuffer, sizeof(djnbuffer), "%T", "DefaultJoinName", LANG_SERVER, CTAG, TAG, CPLAYER, targetname, CUSAGE);
		ReplyToCommand(client, djnbuffer);
		if (GetConVarBool(changename_debug))
			{
				LogToFile(LOGPATH, "%s %s is the name they had when they joined the server.", LOGTAG, targetname);
				LogToFile(LOGPATH, "%s %N executed sm_oname on %s but is their original name.", LOGTAG, client, targetname);
			}
	}
	return Plugin_Handled;	
}
public Action Command_Name(int client, int args)
{
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
				char ncdbuffer[128];
				Format(ncdbuffer, sizeof(ncdbuffer), "%T", "NameChangeDisabled", LANG_SERVER, CTAG, TAG, CERROR);
				ReplyToCommand(client, ncdbuffer);
				return Plugin_Handled;
			}
		}
	} else 
	{
		if (client == 0)
		{
			PrintToServer("%s This plugin is currently disabled. Contact an administrator!", TAG);
			if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
					LogToFile(LOGPATH, "%s %N attempted a name change but plugin is disabled.", LOGTAG, client);
				}
			return Plugin_Handled;
		} else {
			char pbuffer[128];
			Format(pbuffer, sizeof(pbuffer), "%T", "PluginDisabled", LANG_SERVER, CTAG, TAG, CERROR);
			ReplyToCommand(client, pbuffer);
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
	if(args == 0)
	{
		char id[32], buffer[MAX_NAME_LENGTH], currentname[MAX_NAME_LENGTH];
		
		GetClientAuthId(client, AuthId_Steam2, id, sizeof(id));
		
		g_names.GetString(id, buffer, sizeof(buffer));
		
		GetClientName(client, currentname, sizeof(currentname));
		
		if(!CanChangeName[client])
		{
			char cooldown[128];
			Format(cooldown, sizeof(cooldown), "%T", "NameCooldown", LANG_SERVER, CTAG, TAG, CPLAYER);
			PrintToChat(client, cooldown);
			//PrintToChat(client, "[NAME] Please wait a few seconds before changing your name again.");
			return Plugin_Handled;
		}
		
		if(strcmp(buffer, currentname, true))
		{
			SetClientName(client, buffer);
			
			//He reset his name
			char nrbuffer[128];
			Format(nrbuffer, sizeof(nrbuffer), "%T", "NameReset", LANG_SERVER, CTAG, TAG, CPLAYER, currentname, CUSAGE, CPLAYER, buffer, CLIME);
			PrintToChatAll(nrbuffer);
			if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Player %s has reset their name to %s", LOGTAG, currentname, buffer);
				}
		}
		else
		{
			//Or the name is already set to original name
			char nsbuffer[128];
			Format(nsbuffer, sizeof(nsbuffer), "%T", "NameAlreadySet", LANG_SERVER, CTAG, TAG, CUSAGE, CPLAYER, currentname, CUSAGE);
			PrintToChat(client, nsbuffer);
			if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Player %s has not changed their name from their original one (name on connection) but has still attempted to reset their name to the one they had on server connection.", LOGTAG, currentname);
				}
		}
		return Plugin_Handled;
	}

	//Let the player change his name in-game
	if(!CanChangeName[client])
	{
		char cooldown2[128];
		Format(cooldown2, sizeof(cooldown2), "%T", "NameCooldown", LANG_SERVER, CTAG, TAG, CPLAYER);
		PrintToChat(client, cooldown2);
		//PrintToChat(client, "[NAME] Please wait a few seconds before changing your name again.");
		return Plugin_Handled;
	}
	
	if(args > 0)
	{ 
		char sName[MAX_NAME_LENGTH], currentname[MAX_NAME_LENGTH], steamid[32];
		
		GetClientName(client, currentname, sizeof(currentname));
		
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		
		GetCmdArgString(sName, sizeof(sName));
		
		if(strcmp(sName, currentname))
			{
				//He changed his name
				Handle DP = CreateDataPack();
			
				RequestFrame(TwoTotalFrames, DP);
				WritePackCell(DP, GetClientUserId(client));
				WritePackString(DP, sName);
				CanChangeName[client] = false;
				CreateTimer(NAME_COOLDOWN, ResetCooldown, client);
					
				char ncbuffer[128];
				Format(ncbuffer, sizeof(ncbuffer), "%T", "NameChanged", LANG_SERVER, CTAG, TAG, CPLAYER, currentname, CUSAGE, CPLAYER, sName, CUSAGE);
				PrintToChatAll(ncbuffer);
				if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s %s has changed their name to %s.", LOGTAG, currentname, sName);
				}
			}
			else
			{
				//Name already set to the one he wants to set it to?
				char nasbuffer[128];
				Format(nasbuffer, sizeof(nasbuffer), "%T", "NewNameAlreadySet", LANG_SERVER, CTAG, TAG, CUSAGE, CPLAYER, currentname, CUSAGE);
				PrintToChat(client, nasbuffer);
				if (GetConVarBool(changename_debug))
					{
						LogToFile(LOGPATH, "%s %s has initiated an sm_name usage using a name that was already identical to the one they have.", LOGTAG, currentname);
					}
			}
				
	}
	
	return Plugin_Handled;
}

public Action ResetCooldown(Handle Timer, any client)
{
	CanChangeName[client] = true;
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
	
	char NewName[64];
	ReadPackString(DP, NewName, sizeof(NewName));
	CloseHandle(DP);
	SetClientInfo(client, "name", NewName);
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
				char fsnbuffer[128];
				Format(fsnbuffer, sizeof(fsnbuffer), "%T", "SteamNameFetchDisabled", LANG_SERVER, CTAG, TAG, CERROR);
				ReplyToCommand(client, fsnbuffer);
				return Plugin_Handled;
			}
		}
	} else 
	{
		if (client == 0)
		{
			PrintToServer("%s This plugin is currently disabled. Contact an administrator!", TAG);
			if (GetConVarBool(changename_debug))
				{
					LogToFile(LOGPATH, "%s Plugin disabled.", LOGTAG);
					LogToFile(LOGPATH, "%s %N attempted to fetch a Steam name but plugin is disabled.", LOGTAG, client);
				}
			return Plugin_Handled;
		} else {
			char pbuffer[128];
			Format(pbuffer, sizeof(pbuffer), "%T", "PluginDisabled", LANG_SERVER, CTAG, TAG, CERROR);
			ReplyToCommand(client, pbuffer);
			return Plugin_Handled;
		}
	}

	if (args < 1)
	{
		ReplyToCommand(client, "%s%s %sUsage: %ssm_sname <#userid|name>", CTAG, TAG, CUSAGE, CLIME);
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
	if (result != ConVarQuery_Okay)
	{
		char snrbuffer[128];
		Format(snrbuffer, sizeof(snrbuffer), "%T", "SteamNameNotReset", LANG_SERVER, CTAG, TAG, CERROR);
		PrintToChat(client, snrbuffer);
		return;
	}	
	
	if (client <= 0 || client > MaxClients)
		return;
		
	else if(!IsClientInGame(client))
		return;
	
	SetClientInfo(client, "name", cvarValue);	
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
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s Name plugin disabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
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
				else if (IsClientInGame(x) && GetAdminFlag(GetUserAdmin(x), Admin_Root))
				{
					if (GetConVarBool(changename_debug))
					{
						char cbuffer[128];
						Format(cbuffer, sizeof(cbuffer), "%s%s Name change ability disabled.", CLOGTAG, LOGTAG);
						PrintToChat(x, cbuffer);
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
						LogToFile(LOGPATH, "%s %s Steam name reset ability is now enabled.", LOGTAG);
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

/******************************
PLUGIN FUNCTIONS
******************************/
void Debug_Path()
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

//PETER BREV, SIGNING OFF

/*************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
*****************************************************************!AND THE DREAM ENDS HERE!********************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************
**************************************************************************************************************************************************************/
