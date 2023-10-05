/** =============================================================================
 * Change Your Name - Functionality related to displaying name history
 * Displays the last few names used by a player.
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

// Name History Admin Menu

public void AdminMenu_NameHistory(TopMenu topmenu, 
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
			Format(buffer, maxlength, "Name history", param);
		}
		case TopMenuAction_SelectOption:
		{
			DisplayHistoryNameTargetMenu(param);
		}
	}
}

public int MenuHandler_NameHistoryPlayerList(Menu menu, MenuAction action, int param1, int param2)
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
			CheckNameHistory(param1, target);
		}
	}
	return 0;
}

void DisplayHistoryNameTargetMenu(int client)
{
	Menu menu = new Menu(MenuHandler_NameHistoryPlayerList);
	
	char title[100];
	Format(title, sizeof(title), "Name history", client);
	menu.SetTitle(title);
	menu.ExitBackButton = CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, false);
	
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_CONNECTED);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public Action Command_NameHistory(int client, int args)
{
	if (!client) /*Due to the nature of printing the array, this command can only be used in-game*/
	{
		ReplyToCommand(client, "[SM] This command can only be used in-game.");
		return Plugin_Handled;
	}
	
	if (!args)
	{
		ReplyToCommand(client, "[SM] Usage: sm_name_history <#userid|name>");
		return Plugin_Handled;
	}
	
	char arg[MAX_NAME_LENGTH];
	GetCmdArg(1, arg, sizeof(arg));
	
	int Target = FindTarget(client, arg, true, false);
	
	if (Target == -1)
	{
		return Plugin_Handled;
	}
	
	CheckNameHistory(client, Target);
	LogMessage("%L checked the name history of %L.", client, Target);
	
	return Plugin_Handled;
}

void CheckNameHistory(int client, int Target)
{
	char id[32];
	GetClientAuthId(Target, AuthId_SteamID64, id, sizeof(id));
	
	BuildPath(Path_SM, g_sPlayerNameHistory, sizeof(g_sPlayerNameHistory), "Name/%s.txt", id);
	Handle NameHistory = OpenFile(g_sPlayerNameHistory, "a+");
	
	if (NameHistory == INVALID_HANDLE)
	{
		if (!client)
		{
			PrintToServer("[SM] Could not display name history of %N (error opening file).", Target);
			LogError("Could not display name history of %N (error opening file).", Target);
			return;
		}
		
		PrintToChat(client, "[SM] Could not display name history of %N (error opening file).", Target);
		LogError("Could not display name history of %N (error opening file).", Target);
		return;
	}
	
	Handle stringArray = CreateArray(ByteCountToCells(256));
	char linebuffer[256];
	while (ReadFileLine(NameHistory, linebuffer, sizeof(linebuffer)))
	{
		ReplaceString(linebuffer, sizeof(linebuffer), "\n", "", false);
		PushArrayString(stringArray, linebuffer);
	}
	CloseHandle(NameHistory);
	
	int iCount;
	iCount = 0;
	
	int stringArraySize = GetArraySize(stringArray);
	
	if (stringArraySize == 0)
	{		
		PrintToChat(client, "[SM] This player has no name history.");
		return;
	}
	
	if (stringArraySize <= 10)
	{
		{
			Handle NameHistoryLessThan10 = OpenFile(g_sPlayerNameHistory, "a+");
			
			while (ReadFileLine(NameHistoryLessThan10, linebuffer, sizeof(linebuffer)))
			{
				iCount++;
				ReplaceString(linebuffer, sizeof(linebuffer), "\n", "", false);			
				PrintToConsole(client, "%i. %s", iCount, linebuffer);
			}		
			if (GetCmdReplySource() == SM_REPLY_TO_CHAT)PrintToChat(client, "[SM] See console for details.");
			CloseHandle(NameHistoryLessThan10);
			return;
		}
	}
	
	for (int i = stringArraySize - 10; i < stringArraySize; i++)
	{
		iCount++;
		GetArrayString(stringArray, i, linebuffer, sizeof(linebuffer));
		PrintToConsole(client, "%i. %s", iCount, linebuffer);
	}
	if (GetCmdReplySource() == SM_REPLY_TO_CHAT)PrintToChat(client, "[SM] See console for details.");
	PrintToConsole(client, "[SM] Printing the last 10 names used. If you need to view the full history, check Name/%s.txt", id);
	CloseHandle(stringArray);
	return;
} 