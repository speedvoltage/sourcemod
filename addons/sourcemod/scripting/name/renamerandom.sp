/** =============================================================================
 * Change Your Name - Functionality related to random renaming
 * Rename a player with a random name.
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

// Rename Random Admin Menu
public void AdminMenu_RenameRandom(TopMenu topmenu, 
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
			Format(buffer, maxlength, "Randomize Name", param);
		}
		case TopMenuAction_SelectOption:
		{
			DisplayRandomizeNameTargetMenu(param);
		}
	}
}

public int MenuHandler_RandomNamePlayerList(Menu menu, MenuAction action, int param1, int param2)
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
			if (CheckCommandAccess(target, "sm_admin", ADMFLAG_GENERIC, false))
			{
				PrintToChat(param1, "[SM] You cannot target an admin.");
				return 0;
			}
			PerformRandomizedName(target);
			g_iRenameTracker++;
			g_iWasRenamed[target]++;
		}
	}
	return 0;
}

void DisplayRandomizeNameTargetMenu(int client)
{
	Menu menu = new Menu(MenuHandler_RandomNamePlayerList);
	
	char title[100];
	Format(title, sizeof(title), "Randomize name", client);
	menu.SetTitle(title);
	menu.ExitBackButton = CheckCommandAccess(client, "sm_admin", ADMFLAG_GENERIC, false);
	
	AddTargetsToMenu2(menu, client, COMMAND_FILTER_NO_BOTS | COMMAND_FILTER_CONNECTED);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public Action Command_RenameRandom(int client, int args)
{
	if (!args)
	{
		ReplyToCommand(client, "[SM] Usage: sm_name_random <#userid|name>");
		return Plugin_Handled;
	}
	
	char arg[MAX_NAME_LENGTH];
	
	GetCmdArg(1, arg, sizeof(arg));
	
	int Target = FindTarget(client, arg, true, false);
	
	if (Target == -1)/*Since we do not need players to use @all or similar, we are limiting it to one player at a time*/
	{
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
	
	ShowActivity2(client, "[SM] ", "Scrambled %N's name.", Target);
	LogAction(client, Target, "%L scrambled %L's name.", client, Target);
	PerformRandomizedName(Target);
	g_iRenameTracker++;
	g_iWasRenamed[Target]++;
	return Plugin_Handled;
} 

void PerformRandomizedName(int target)
{
	char name[MAX_NAME_LENGTH];
	GetClientName(target, name, sizeof(name));
	
	int len = strlen(name);
	g_targetnewname[target][0] = '\0';
	
	for (int i = 0; i < len; i++)
	{
		g_targetnewname[target][i] = name[GetRandomInt(0, len - 1)];
	}
	g_targetnewname[target][len] = '\0';
	SetClientName(target, g_targetnewname[target]);
}