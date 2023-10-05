/** =============================================================================
 * Change Your Name - Functionality related to resetting a player's name
 * Forcibly resets a name to what they had when they connected to the server.
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

// Name Reset Admin Menu

public void AdminMenu_NameReset(TopMenu topmenu, 
	TopMenuAction action, 
	TopMenuObject object_id, 
	int param, 
	char[] buffer, 
	int maxlength)
{
	switch (action)
	{
		case TopMenuAction_DisplayOption:
		{
			Format(buffer, maxlength, "Name reset", param);
		}
		case TopMenuAction_SelectOption:
		{
			DisplayResetNameTargetMenu(param);
		}
	}
}

public int MenuHandler_NameResetPlayerList(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		delete menu;
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack && hAdminMenu)
		{
			hAdminMenu.Display(param1, TopMenuPosition_LastCategory);
		}
	}
	else if (action == MenuAction_Select)
	{
		char info[32], name[32];
		int userid, target;
		
		menu.GetItem(param2, info, sizeof(info), _, name, sizeof(name));
		userid = StringToInt(info);
		
		if ((target = GetClientOfUserId(userid)) == 0)
		{
			PrintToChat(param1, "[SM] Player is no longer available.");
		}
		else if (!CanUserTarget(param1, target))
		{
			PrintToChat(param1, "[SM] Cannot target player.");
		}
		else
		{
			char id[32], currentname[MAX_NAME_LENGTH], buffer[MAX_NAME_LENGTH];
			GetClientName(target, currentname, sizeof(currentname));
			GetClientAuthId(target, AuthId_Steam2, id, sizeof(id));
			g_names.GetString(id, buffer, sizeof(buffer));
			
			if (g_bMapReload)
			{
				PrintToChat(param1, "[SM] This plugin was restarted. Please wait for the next map or reconnect.");
				return 0;
			}
			
			if (g_bClientAuthorized[target])
			{
				PrintToChat(param1, "[SM] This player's SteamID was not verified yet. Please wait before trying to reset their name.");
				return 0;
			}
			
			if (g_bForcedName[target])
			{
				PrintToChat(param1, "[SM] This player was recently forced renamed. Remove the forced locked name first to reset their name.");
				return 0;
			}
			
			if (g_bAdminRenamed[target])
			{
				PrintToChat(param1, "[SM] %N was recently renamed and is under cooldown. You must wait until the cooldown is over to reset this player's name.", target);
				return 0;
			}
			
			if (CheckCommandAccess(target, "sm_admin", ADMFLAG_GENERIC, false))
			{
				PrintToChat(param1, "[SM] You cannot target an admin.");
				return 0;
			}
			
			if (StrEqual(buffer, ""))
			{
				PrintToChat(param1, "[SM] Could not reset their name (name was not stored in memory).");
				return 0;
			}
			
			if (strcmp(buffer, currentname, false))
			{
				g_bAdminRenamed[target] = true;
				ResetName(target, buffer);
			}
			
			else
			{
				PrintToChat(param1, "[SM] Their name is already set to %s.", currentname);
			}
		}
	}
	return 0;
}

void DisplayResetNameTargetMenu(int client)
{
	Menu menu = new Menu(MenuHandler_NameResetPlayerList);
	
	char title[100];
	Format(title, sizeof(title), "Name reset", client);
	menu.SetTitle(title);
	menu.ExitBackButton = CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, false);
	
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_CONNECTED);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public Action Command_NameReset(int client, int args)
{
	if (!args)
	{
		ReplyToCommand(client, "[SM] Usage: sm_rename_reset <#userid|name>");
		return Plugin_Handled;
	}
	
	char arg[MAX_NAME_LENGTH];
	GetCmdArgString(arg, sizeof(arg)); /*Allows for searching names with white spaces in case of multiple people with similar names*/
	
	int Target = FindTarget(client, arg, true, false);
	
	if (Target == -1)/*Since we do not need players to use @all or similar, we are limiting it to one player at a time*/
	{
		return Plugin_Handled;
	}
	
	if (g_bClientAuthorized[Target])
	{
		ReplyToCommand(client, "[SM] Their Steam ID was not yet authorized.");
		return Plugin_Handled;
	}
	
	if (CheckCommandAccess(Target, "sm_admin", ADMFLAG_GENERIC))
	{
		ReplyToCommand(client, "[SM] You cannot target an admin.");
		return Plugin_Handled;
	}
	
	if (g_bForcedName[Target])
	{
		ReplyToCommand(client, "[SM] %N was recently forced renamed. Remove the forced locked name first to rename this player.", Target);
		return Plugin_Handled;
	}
	
	char id[32], currentname[MAX_NAME_LENGTH], buffer[MAX_NAME_LENGTH], filebuffer[MAX_NAME_LENGTH], bantime = GetConVarInt(changename_bantime);
	GetClientName(Target, currentname, sizeof(currentname));
	GetClientAuthId(Target, AuthId_Steam2, id, sizeof(id));
	g_names.GetString(id, buffer, sizeof(buffer));
	
	for (int i, num = hBadNames.Length; i < num; i++)
	{
		if (!CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC))
		{
			if (hBadNames.GetString(i, filebuffer, sizeof(filebuffer)) && StrContains(buffer, filebuffer, false) != -1)
			{
				if (bantime == -2)
				{
					ReplyToCommand(client, "[SM] Their name was not restored, because it is banned.");
					return Plugin_Handled;
				}
			}
		}
	}
	
	if (strcmp(buffer, "") == 0)
	{
		ReplyToCommand(client, "[SM] Error: name not stored in memory.");
		LogError("%L's name was not reset. No name stored in memory.", Target);
		return Plugin_Handled;
	}
	
	if (strcmp(currentname, buffer) == 0)
	{
		ReplyToCommand(client, "[SM] Their name is already set to the name they connected to the server with.");
		return Plugin_Stop;
	}
	
	if (g_bAdminRenamed[Target])delete g_hTimer[Target]; /*We do not want multiple timers on the same target*/
	
	ResetName(Target, buffer);
	ShowActivity2(client, "[SM] ", "Restored %N's name.", Target);
	LogAction(client, Target, "%L restored %L's name: %s.", client, Target, buffer);
	
	return Plugin_Handled;
}

void ResetName(int Target, const char[] buffer)
{
	int timeleft = GetConVarInt(changename_adminrename_cooldown);
	int mins, secs;
	if (timeleft > 0)
	{
		mins = timeleft / 60;
		secs = timeleft % 60;
		PrintToChat(Target, "[SM] An admin renamed you. You have been temporarily banned from changing names for %d:%02d.", mins, secs);
	}
	
	Handle DP = CreateDataPack();
	WritePackCell(DP, GetClientUserId(Target));
	g_hTimer[Target] = CreateTimer(GetConVarFloat(changename_adminrename_cooldown), name_temp_ban, DP);
	DataPack pack;
	g_bAdminRenamed[Target] = true;
	g_hNoRename[Target] = CreateDataTimer(5.0, NoSteamRenameTimer, pack, TIMER_REPEAT);
	pack.WriteCell(Target);
	pack.WriteString(buffer);
	g_iNameResetTracker++;
	g_iWasRenamed[Target]++;
	
	SetClientName(Target, buffer);
}

public Action NoSteamRenameTimer(Handle timer, DataPack pack)
{
	pack.Reset();
	char buffer[MAX_NAME_LENGTH], currentname[MAX_NAME_LENGTH];
	int Target;
	
	Target = pack.ReadCell();
	pack.ReadString(buffer, sizeof(buffer));
	if (!g_bAdminRenamed[Target])
	{
		g_hNoRename[Target] = null;
		return Plugin_Stop;
	}
	
	GetClientName(Target, currentname, sizeof(currentname));
	
	if (strcmp(currentname, buffer, false) != 0)
	{
		SetClientName(Target, buffer);
		PrintToChat(Target, "[SM] Due to a name reset, your recent Steam name change has been ignored.");
	}
	
	return Plugin_Continue;
}
