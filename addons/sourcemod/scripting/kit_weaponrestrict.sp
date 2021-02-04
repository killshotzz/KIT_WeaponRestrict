/*
 * SourceMod Kitsune Projects
 * by: Kitsune Lab
 *
 * Copyright (C) 2021 Kitsune-Lab
 *
 * This program is free software: you can redistribute it and/or modify it
 * under the terms of the GNU General Public License as published by the Free
 * Software Foundation, either version 3 of the License, or (at your option) 
 * any later version.
 * 
 * This program is distributed in the hope that it will be useful, but WITHOUT
 * ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
 * FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
 * details.
 *
 * You should have received a copy of the GNU General Public License along with
 * this program.  If not, see <http://www.gnu.org/licenses/>.
 */
 
#include 	<sourcemod>
#include 	<autoexecconfig>
#include 	<emperor>
#include 	<multicolors>

/*		 _   ___ _                        
/		| | / (_) |                       
/		| |/ / _| |_ ___ _   _ _ __   ___ 
/		|    \| | __/ __| | | | '_ \ / _ \
/		| |\  \ | |_\__ \ |_| | | | |  __/
/		\_| \_/_|\__|___/\__,_|_| |_|\___|
*/

#pragma 	semicolon 1
#pragma 	newdecls required

public Plugin myinfo = 
{
	name 		= "Weapon Restrict", 
	author 		= "Kitsune Lab", 
	description = "This plugin will help you to restrict weapon count per team or overall", 
	version 	= "1.0",
	url			= "https://github.com/Kitsune-Lab/KIT_WeaponRestrict"
};


/*		 _____             _   _                
/		/  __ \           | | | |               
/		| /  \/ ___  _ __ | | | | __ _ _ __ ___ 
/		| |    / _ \| '_ \| | | |/ _` | '__/ __|
/		| \__/\ (_) | | | \ \_/ / (_| | |  \__ \
/		 \____/\___/|_| |_|\___/ \__,_|_|  |___/
*/

ConVar		gConVar_Kitsune_WeaponRestrict_Enabled,
			gConVar_Kitsune_WeaponRestrict_Prefix,
			gConVar_Kitsune_WeaponRestrict_Bypass;


/*		______ _             _       
/		| ___ \ |           (_)      
/		| |_/ / |_   _  __ _ _ _ __  
/		|  __/| | | | |/ _` | | '_ \ 
/		| |   | | |_| | (_| | | | | |
/		\_|   |_|\__,_|\__, |_|_| |_|
/		                __/ |
/		               |___/ 
*/

StringMap 	g_smKitsune_WeaponIndex;

char 		g_cKitsune_WeaponList[][] = {
/* 0*/ "weapon_awp", 		/* 1*/ "weapon_ak47", 	/* 2*/ "weapon_m4a1", 		/* 3*/ "weapon_m4a1_silencer", 	/* 4*/ "weapon_deagle", 	/* 5*/ "weapon_usp_silencer", 	/* 6*/ "weapon_hkp2000", 	/* 7*/ "weapon_glock", 	/* 8*/ "weapon_elite", 
/* 9*/ "weapon_p250", 		/*10*/ "weapon_cz75a", 	/*11*/ "weapon_fiveseven", 	/*12*/ "weapon_tec9", 			/*13*/ "weapon_revolver", 	/*14*/ "weapon_nova", 			/*15*/ "weapon_xm1014", 	/*16*/ "weapon_mag7", 	/*17*/ "weapon_sawedoff", 
/*18*/ "weapon_m249", 		/*19*/ "weapon_negev", 	/*20*/ "weapon_mp9", 		/*21*/ "weapon_mac10", 			/*22*/ "weapon_mp7", 		/*23*/ "weapon_ump45", 			/*24*/ "weapon_p90", 		/*25*/ "weapon_bizon", 	/*26*/ "weapon_famas",
/*27*/ "weapon_galilar", 	/*28*/ "weapon_ssg08", 	/*29*/ "weapon_aug", 		/*30*/ "weapon_sg556", 			/*31*/ "weapon_scar20", 	/*32*/ "weapon_g3sg1"
};

#define 	Kitsune_RestrictRule_Block			0
#define 	Kitsune_RestrictRule_All			1
#define 	Kitsune_RestrictRule_Team			2
#define 	Kitsune_RestrictRule_Players		3

#define 	Kitsune_Team_All					0
#define 	Kitsune_Team_T						1
#define 	Kitsune_Team_CT						2

char		g_cKitsune_Prefix[256];		

int			g_iKitsune_RestrictRules[sizeof(g_cKitsune_WeaponList)][4];
int			g_iKitsune_WeaponCount[sizeof(g_cKitsune_WeaponList)][3];

public void OnPluginStart()
{
	EMP_DirExistsEx("cfg/Kitsune");
	
	LoadTranslations("kit_weaponrestrict.phrases");
	
	AutoExecConfig_SetFile("WeaponRestrict", "Kitsune");
	AutoExecConfig_SetCreateFile(true);
	
	gConVar_Kitsune_WeaponRestrict_Enabled	= AutoExecConfig_CreateConVar("kit_weapon_restrict_enabled", 			"1" ,													"Enable or Disable the plugin", 0, true, 0.0, true, 1.0);
	gConVar_Kitsune_WeaponRestrict_Prefix 	= AutoExecConfig_CreateConVar("kit_weapon_restrict_prefix", 			"{default}[{lightred}Kitsune{default} ]{lime}", 		"Modify the plugin's chat prefix");
	gConVar_Kitsune_WeaponRestrict_Bypass 	= AutoExecConfig_CreateConVar("kit_weapon_restrict_bypass", 			"z", 													"This flag can bypass weapon restrictions (leave empty for none)");

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();
	
	HookEvent("round_end", 		Restrict_RoundEnd);
	HookEvent("player_spawn", 	Restrict_PlayerSpawn);
	HookConVarChange(gConVar_Kitsune_WeaponRestrict_Prefix, OnPrefixChange);
}

public void OnConfigsExecuted()
{
	if (gConVar_Kitsune_WeaponRestrict_Enabled.BoolValue)
	{
		Kitsune_ReadConfig();
		SavePrefix();
	}
}

public void OnPrefixChange(ConVar cvar, char[] oldvalue, char[] newvalue)
{
	if (gConVar_Kitsune_WeaponRestrict_Enabled.BoolValue)
		SavePrefix();
}

public Action Restrict_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	if (gConVar_Kitsune_WeaponRestrict_Enabled.BoolValue)
	{
		int client = GetClientOfUserId(GetEventInt(event, "userid"));
		if (!EMP_IsWarmUpPeriod() && EMP_IsValidClient(client))
		{
			Kitsune_CheckPlayerWeapons(client);
		}
	}
}

public Action Restrict_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (gConVar_Kitsune_WeaponRestrict_Enabled.BoolValue)
	{
		for (int a = 0; a < sizeof(g_cKitsune_WeaponList); a++)
		{
			for (int b = 0; b < Kitsune_Team_CT; b++)
			{
				g_iKitsune_WeaponCount[a][b] = 0;
			}
		}
	}
}

public Action CS_OnBuyCommand(int client, const char[] weapon)
{
	if (EMP_IsValidClient(client) && gConVar_Kitsune_WeaponRestrict_Enabled.BoolValue)
	{
		bool bIsAdmin = false;
		char cBuffer[32];
		gConVar_Kitsune_WeaponRestrict_Bypass.GetString(EMP_STRING(cBuffer));
		if (StrContains("abcdefghijklmnopqrstz", cBuffer) != -1)
		{
			if (Client_HasAdminFlags(client, EMP_Flag_StringToInt(cBuffer)))
			{
				//bIsAdmin = true;
			}
		}
		
		int iIndex;
		FormatEx(EMP_STRING(cBuffer), "weapon_%s", weapon);
		if(g_smKitsune_WeaponIndex.GetValue(cBuffer, iIndex))
		{
			if (!bIsAdmin)
			{
				if (g_iKitsune_RestrictRules[iIndex][Kitsune_RestrictRule_Block] == 1)
				{
					CPrintToChat(client, "%s %t", g_cKitsune_Prefix, "Blocked_1");
					return Plugin_Handled;
				}
				else
				{
					if (g_iKitsune_RestrictRules[iIndex][Kitsune_RestrictRule_All] != 0)
					{
						if (g_iKitsune_WeaponCount[iIndex][Kitsune_Team_All] >= g_iKitsune_RestrictRules[iIndex][Kitsune_RestrictRule_All])
						{
							CPrintToChat(client, "%s %t", g_cKitsune_Prefix, "Blocked_2", g_iKitsune_WeaponCount[iIndex][Kitsune_Team_All]);
							return Plugin_Handled;
						}
					}
					
					if (g_iKitsune_RestrictRules[iIndex][Kitsune_RestrictRule_Team] != 0)
					{
						if (g_iKitsune_WeaponCount[iIndex][GetClientTeam(client) - 1] >= g_iKitsune_RestrictRules[iIndex][Kitsune_RestrictRule_Team])
						{
							CPrintToChat(client, "%s %t", g_cKitsune_Prefix, "Blocked_3", g_iKitsune_RestrictRules[iIndex][Kitsune_RestrictRule_Team]);
							return Plugin_Handled;
						}
					}
					
					if (g_iKitsune_RestrictRules[iIndex][Kitsune_RestrictRule_Players] != 0)
					{
						int iAllowed = EMP_GetPlayers(false) / g_iKitsune_RestrictRules[iIndex][Kitsune_RestrictRule_Players];
						
						if (g_iKitsune_WeaponCount[iIndex][GetClientTeam(client) - 1] >= iAllowed)
						{
							CPrintToChat(client, "%s %t", g_cKitsune_Prefix, "Blocked_4", iAllowed);
							return Plugin_Handled;
						}
					}
				}
				
				g_iKitsune_WeaponCount[iIndex][Kitsune_Team_All]++;
				g_iKitsune_WeaponCount[iIndex][GetClientTeam(client) - 1]++;
			}
			GivePlayerItem(client, cBuffer);
		}
	}
	return Plugin_Handled;
}

/*		   _____ _             _        
/		  / ____| |           | |       
/		 | (___ | |_ ___   ___| | _____ 
/		  \___ \| __/ _ \ / __| |/ / __|
/		  ____) | || (_) | (__|   <\__ \
/		 |_____/ \__\___/ \___|_|\_\___/
*/

public void Kitsune_CheckPlayerWeapons(int client)
{
	if (!EMP_IsValidClient(client)) return;
	
	int iWeaponCount = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	
	char cBuffer[32];
	int iIndex, iWeapon;
	for (int i = 0; i < iWeaponCount; i++)
	{
		iWeapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		if (iWeapon >= 0 && EMP_IsValidWeapon(iWeapon))
		{
			EMP_SetWeaponClassname(iWeapon, EMP_STRING(cBuffer));
			if(g_smKitsune_WeaponIndex.GetValue(cBuffer, iIndex))
			{
				g_iKitsune_WeaponCount[iIndex][Kitsune_Team_All]++;
				g_iKitsune_WeaponCount[iIndex][GetClientTeam(client) - 1]++;
			}
		}
	}
}

public void Kitsune_ReadConfig()
{
	char iPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, EMP_STRING(iPath), "configs/Kitsune/restrict_rules.txt");
	
	if (!FileExists(iPath))
	{
		SetFailState("The Restrict Rules file is missing. ( configs/Kitsune/restrict_rules.txt )");
		return;
	}
	
	KeyValues ConfigLoader = CreateKeyValues("Kitsune_WeaponRestrict");
	ConfigLoader.ImportFromFile(iPath);
	
	if (!ConfigLoader.GotoFirstSubKey())
	{
		SetFailState("The Restrict Rules are empty. ( configs/Kitsune/restrict_rules.txt )");
		return;
	}
	
	delete g_smKitsune_WeaponIndex;
	g_smKitsune_WeaponIndex = new StringMap();
	
	for (int i = 0; i < sizeof(g_cKitsune_WeaponList); i++)
		g_smKitsune_WeaponIndex.SetValue(g_cKitsune_WeaponList[i], i);
	
	char cBuffer[32];
	
	int index;
	do
	{
		ConfigLoader.GetSectionName(EMP_STRING(cBuffer));
		if(g_smKitsune_WeaponIndex.GetValue(cBuffer, index))
		{
			for (int i = 0; i < Kitsune_RestrictRule_Players; i++)
				g_iKitsune_RestrictRules[index][i] = 0;
		
			g_iKitsune_RestrictRules[index][Kitsune_RestrictRule_All]	 	= ConfigLoader.GetNum("all");
			g_iKitsune_RestrictRules[index][Kitsune_RestrictRule_Team] 		= ConfigLoader.GetNum("team");
			g_iKitsune_RestrictRules[index][Kitsune_RestrictRule_Players] 	= ConfigLoader.GetNum("players");
			g_iKitsune_RestrictRules[index][Kitsune_RestrictRule_Block] 	= ConfigLoader.GetNum("block");
		}
		else
			LogError("The Restrict Rules contains an invalid weapon. ( '%s' )", cBuffer);
	}
	while (ConfigLoader.GotoNextKey());
	delete ConfigLoader;
}

public void SavePrefix()
{
	char cBuffer[256];
	GetConVarString(gConVar_Kitsune_WeaponRestrict_Prefix, EMP_STRING(cBuffer));
	FormatEx(EMP_STRING(g_cKitsune_Prefix), "%s ", cBuffer);
	EMP_ProcessColors(EMP_STRING(g_cKitsune_Prefix));
}