/** =============================================================================
 * Change Your Name - Functionality related to force renaming
 * Forcibly rename a player to specific name.
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

public Action Command_NameForce(int client, int args)
{
	if (args < 2)
	{
		ReplyToCommand(client, "[SM] Usage: sm_rename_force <#userid|name> <new name>");
		return Plugin_Handled;
	}
	
	char arg[MAX_NAME_LENGTH], arg2[MAX_NAME_LENGTH], currentname[MAX_NAME_LENGTH];
	GetCmdArg(1, arg, sizeof(arg));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	int Target = FindTarget(client, arg, true, false);
	
	if (Target == -1) return Plugin_Handled;
	
	if (CheckCommandAccess(Target, "sm_admin", ADMFLAG_GENERIC))
	{
		ReplyToCommand(client, "[SM] You cannot target an admin.");
		return Plugin_Handled;
	}
	
	if (g_bAdminRenamed[client]) delete g_hTimer[client];	
	
	GetClientName(Target, currentname, sizeof(currentname));
	
	char filebuffer[MAX_NAME_LENGTH];
	
	for (int i, num = hBadNames.Length; i < num; i++)
	{
		if (hBadNames.GetString(i, filebuffer, sizeof(filebuffer)) && StrContains(arg2, filebuffer, false) != -1)
		{
			ReplyToCommand(client, "[SM] %s is banned from being used.", arg2);
			return Plugin_Handled;
		}
	}
	
	if (g_bAdminRenamed[Target]) delete g_hTimer[Target];
	Format(g_targetnewname[Target], MAX_NAME_LENGTH, "%s", arg2);
	ShowActivity2(client, "[SM] ", "Forced renamed %N.", Target);
	if (strcmp(currentname, arg2) == 0) LogAction(client, Target, "%L forced locked %L's current name.", client, Target, arg2);
	else LogAction(client, Target, "%L forced renamed %L to %s.", client, Target, arg2);
	ForceRenamePlayer(Target);
	g_iWasForcedNamed[Target]++;
	g_iForcedNames++;
	return Plugin_Handled;
} 

void ForceRenamePlayer(int target)
{
	char name[MAX_NAME_LENGTH];
	GetClientName(target, name, sizeof(name));
	if (strcmp(name, g_targetnewname[target]) == 0)
	{
		PrintToChat(target, "[SM] Your name has been forced locked. You can no longer change your name.");
		g_bForcedName[target] = true;
		DataPack pack;
		g_hForceLockSteamCheck[target] = CreateDataTimer(5.0, NoSteamNameChange, pack, TIMER_REPEAT);
		pack.WriteCell(target);
		pack.WriteString(name);
		
		return;
	}
	else
	{
		SetClientName(target, g_targetnewname[target]);
		PrintToChat(target, "[SM] You have been forced locked the name %s.", g_targetnewname[target]);
		DataPack pack;
		g_hForceLockSteamCheck[target] = CreateDataTimer(5.0, NoSteamNameChange, pack, TIMER_REPEAT);
		pack.WriteCell(target);
		pack.WriteString(name);
		g_bForcedName[target] = true;
		
		return;
	}
}

public Action NoSteamNameChange(Handle timer, DataPack pack)
{
	char name[MAX_NAME_LENGTH];
	int target;
	
	pack.Reset();
	target = pack.ReadCell();
	pack.ReadString(name, sizeof(name));
	
	if (!IsClientInGame(target)) return Plugin_Stop;
	
	if (!g_bForcedName[target])
	{
		g_hForceLockSteamCheck[target] = null;
		return Plugin_Stop;
	}
	
	char currentname[MAX_NAME_LENGTH];
	GetClientName(target, currentname, sizeof(currentname));
	if (strcmp(currentname, g_targetnewname[target]) != 0)
	{
		SetClientName(target, g_targetnewname[target]);
		PrintToChat(target, "[SM] Due to an active name force-lock, your Steam name change has been ignored on this server.");
	}
	
	return Plugin_Continue;
}

public Action Command_NameUnforce(int client, int args)
{
	if (!args)
	{
		ReplyToCommand(client, "[SM] Usage: sm_rename_unforce <#userid|name>");
		return Plugin_Handled;
	}
	
	char arg[65];
	GetCmdArgString(arg, sizeof(arg));
	
	int Target = FindTarget(client, arg, true, false);
	
	if (Target == -1)
	{
		return Plugin_Handled;
	}
	
	char targetname[MAX_NAME_LENGTH];
	GetClientName(Target, targetname, sizeof(targetname));
	
	if (g_bForcedName[Target] == false)
	{
		ReplyToCommand(client, "[SM] No forced locked name active on %s.", targetname);
		return Plugin_Handled;
	}
	
	g_bForcedName[Target] = false;
	ShowActivity2(client, "[SM] ", "Forced locked name removed on %N.", Target);
	LogAction(client, Target, "%L removed name force lock on %L.", client, Target);
	
	return Plugin_Handled;
}