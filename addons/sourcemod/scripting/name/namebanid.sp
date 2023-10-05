/** =============================================================================
 * Change Your Name - Functionality related to banning/unbanning Steam IDs
 * Add and remove IDs from banned_id.ini, preventing players from changing names.
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

// Name Ban ID Admin Menu
public void AdminMenu_NameBanId(TopMenu topmenu, 
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
			Format(buffer, maxlength, "Name ban player", param);
		}
		case TopMenuAction_SelectOption:
		{
			DisplayNameBanTargetMenu(param);
		}
	}
}

void DisplayNameBanTargetMenu(int client)
{
	Menu menu = new Menu(MenuHandler_BanPlayerList);
	
	char title[100];
	Format(title, sizeof(title), "Name ban player", client);
	menu.SetTitle(title);
	menu.ExitBackButton = CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, false);
	
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_CONNECTED);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int MenuHandler_BanPlayerList(Menu menu, MenuAction action, int param1, int param2)
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
		else if (CheckCommandAccess(target, "sm_admin", ADMFLAG_GENERIC))
		{
			PrintToChat(param1, "[SM] You cannot target an admin.");
			return 0;
		}
		else
		{
			char getsteamid[64];
			GetClientAuthId(target, AuthId_Steam2, getsteamid, 64);
			AddSteamIDBan(param1, getsteamid);
		}
	}
	return 0;
}

public Action Command_SteamidBan(int client, int args)
{
	if (!args)
	{
		ReplyToCommand(client, "[SM] Usage: sm_name_banid <SteamID to ban>");
		return Plugin_Handled;
	}
	
	char arg[32];
	GetCmdArgString(arg, sizeof(arg));
	
	StripQuotes(arg);
	TrimString(arg);
	
	AdminId idAdmin = FindAdminByIdentity("steam", arg);
	
	if (idAdmin != INVALID_ADMIN_ID)
	{
		ReplyToCommand(client, "[SM] You cannot target an admin.");
		return Plugin_Handled;
	}
	
	AddSteamIDBan(client, arg);
	
	return Plugin_Handled;
}

void AddSteamIDBan(int client, const char[] arg)
{
	if (StrContains(arg, "STEAM_", false) == -1)
	{
		if (!client)
		{
			PrintToServer("[SM] This is not a Steam 2 ID (STEAM_0:X:XXXX).");
		}
		
		else
		{
			PrintToChat(client, "[SM] This is not a Steam 2 ID (STEAM_0:X:XXXX).");
		}
		return;
	}
	
	Handle nfile = OpenFile(bannedidfile, "a+");
	
	if (nfile == null)
	{
		if (!client)
		{
			PrintToServer("[SM] Banned Steam IDs file (%s) could not be opened (Path_SM/config/banned_id.ini).", fileName);
			LogError("Banned Steam IDs file (%s) could not be opened (Path_SM/config/banned_id.ini).", fileName);
			return;
		}
		
		else
		{
			PrintToChat(client, "[SM] Banned Steam IDs file (%s) could not be opened (Path_SM/config/banned_id.ini).", fileName);
			LogError("Banned Steam IDs file (%s) could not be opened (Path_SM/config/banned_id.ini).", fileName);
			return;
		}
	}
	
	char linebuffer[256];
	while (ReadFileLine(nfile, linebuffer, sizeof(linebuffer)))ReplaceString(linebuffer, sizeof(linebuffer), "\n", "", false);
	
	WriteFileLine(nfile, arg);
	if (!client)
	{
		PrintToServer("[SM] %s has been added to the banned SteamIDs list.", arg);
	}
	
	else
	{
		PrintToChat(client, "[SM] %s has been added to the banned SteamIDs list.", arg);
	}
	
	CloseHandle(nfile);
	
	LogMessage("%L banned Steam ID %s from changing names.", client, arg);
}

public Action Command_SteamidUnban(int client, int args)
{
	File nfile = OpenFile(bannedidfile, "a+");
	
	if (nfile == null)
	{
		ReplyToCommand(client, "[SM] Banned Steam IDs file (%s) could not be opened (Path_SM/config/banned_id.ini).", bannedidfile);
		LogError("Banned Steam IDs file (%s) could not be opened (Path_SM/config/banned_id.ini).", bannedidfile);
		return Plugin_Handled;
	}
	
	if (!args)
	{
		ReplyToCommand(client, "[SM] Usage: sm_name_unbanid <SteamID to unban>");
		return Plugin_Handled;
	}
	
	char arg1[32], arg2[32];
	
	GetCmdArgString(arg2, sizeof(arg2));
	
	StripQuotes(arg2);
	TrimString(arg2);
	
	bool found = false;
	ArrayList fileArray = CreateArray(32);
	
	while (!nfile.EndOfFile() && nfile.ReadLine(arg1, sizeof(arg1)))
	{
		if (strlen(arg1) < 1 || IsCharSpace(arg1[0]))continue;
		ReplaceString(arg1, sizeof(arg1), "\n", "", false);
		if (!StrEqual(arg1, arg2, false))
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
			ReplyToCommand(client, "[SM] Banned Steam IDs file (%s) could not be opened (Path_SM/config/banned_id.ini).", bannedidfile);
			LogError("Banned Steam IDs file (%s) could not be opened (Path_SM/config/banned_id.ini).", bannedidfile);
			return Plugin_Handled;
		}
		
		ReplyToCommand(client, "[SM] %s has been removed from the banned SteamIDs list.", arg2);
		LogMessage("%s removed from ban Steam IDs list by %L.", arg2, client);
		
		for (int i = 0; i < GetArraySize(fileArray); i++)
		{
			char writeLine[32];
			fileArray.GetString(i, writeLine, sizeof(writeLine));
			newFile.WriteLine(writeLine);
		}
		
		delete newFile;
		delete fileArray;
		return Plugin_Handled;
	}
	else
	{
		ReplyToCommand(client, "[SM] This SteamID could not be found.");
		return Plugin_Handled;
	}
} 