//reimplementation of RegenThink to allow fine grained callbacks and control

#include <sourcemod>
#include <sdkhooks>
#include <dhooks>
#include <tf2>
#include <tf2_stocks>
#include <tf2attributes>

#pragma newdecls required
#pragma semicolon 1

#define TF_REGEN_THINK_INTERVAL 1.0
#define TF_REGEN_HEALTH 3.0
#define TF_REGEN_AMMO_INTERVAL 5.0

#define PLUGIN_VERSION "22w44a"

public Plugin myinfo = {
	name = "[TF2] Regen Think Hooks",
	author = "reBane",
	description = "Library to control health ammo and metal regen",
	version = PLUGIN_VERSION,
	url = "https://github.com/DosMike/TF2-RegenThinkHook"
}

Handle sc_CTFPlayer_TakeHealth;
Handle sc_CTFPlayer_RegenAmmo;
Handle sc_CBaseEntity_ThinkSet;
Address addr_CTFPlayer_RegenThink;
DynamicDetour dt_CTFPlayer_RegenThink;

int off_CTFPlayer_m_flLastHealthRegenAt;
int off_CTFPlayer_m_flAccumulatedHealthRegen;
int off_CTFPlayer_m_flNextAmmoRegenAt;

GlobalForward fwd_RegenThinkPre;
GlobalForward fwd_RegenThinkHealth;
GlobalForward fwd_RegenThinkAmmo;
GlobalForward fwd_RegenThinkPost;

public void OnPluginStart() {
	GameData data = new GameData("tf2rth.games");
	
	// allows us to use the engines scheduler to re-schedule the think function
	StartPrepSDKCall(SDKCall_Entity);
	PrepSDKCall_SetAddress(data.GetMemSig("CBaseEntity::ThinkSet()"));
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //function
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain); //next invocation
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Plain); //context name
	PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Pointer); //returns the function pointer for chain-calling i guess
	if ((sc_CBaseEntity_ThinkSet = EndPrepSDKCall()) == INVALID_HANDLE)
		SetFailState("Failed to prepare call to CBaseEntity::ThinkSet()");
	
	// at some point we need to apply the health
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetVirtual(data.GetOffset("CTFPlayer::TakeHealth()"));
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //hp
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //damage flags?
	if ((sc_CTFPlayer_TakeHealth = EndPrepSDKCall()) == INVALID_HANDLE)
		SetFailState("Failed to prepare call to CTFPlayer::TakeHealth()");
	
	// and regen ammo
	StartPrepSDKCall(SDKCall_Player);
	PrepSDKCall_SetAddress(data.GetMemSig("CBaseEntity::RegenAmmoInternal()"));
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); //ammo type
	PrepSDKCall_AddParameter(SDKType_Float, SDKPass_Plain); //regen amount (0..1 in %)
	if ((sc_CTFPlayer_RegenAmmo = EndPrepSDKCall()) == INVALID_HANDLE)
		SetFailState("Failed to prepare call to CBaseEntity::RegenAmmoInternal()");
	
	//get the address for think scheduling
	addr_CTFPlayer_RegenThink = data.GetMemSig("CTFPlayer::RegenThink()");
	if (addr_CTFPlayer_RegenThink == Address_Null)
		SetFailState("Failed to look up CTFPlayer::RegenThink()");
	
	//hook the think method
	dt_CTFPlayer_RegenThink = DynamicDetour.FromConf(data, "CTFPlayer::RegenThink()");
	
	//unmapped offsets
	off_CTFPlayer_m_flLastHealthRegenAt = data.GetOffset("CTFPlayer::m_flLastHealthRegenAt");
	off_CTFPlayer_m_flAccumulatedHealthRegen = data.GetOffset("CTFPlayer::m_flAccumulatedHealthRegen");
	off_CTFPlayer_m_flNextAmmoRegenAt = data.GetOffset("CTFPlayer::m_flNextAmmoRegenAt");
	
	delete data;
	
	//setup forwards
	fwd_RegenThinkPre = CreateGlobalForward("TF2_OnClientRegenThinkPre", ET_Hook, Param_Cell);
	fwd_RegenThinkHealth = CreateGlobalForward("TF2_OnClientRegenThinkHealth", ET_Event, Param_Cell, Param_FloatByRef, Param_FloatByRef);
	fwd_RegenThinkAmmo = CreateGlobalForward("TF2_OnClientRegenThinkAmmo", ET_Event, Param_Cell, Param_FloatByRef, Param_CellByRef);
	fwd_RegenThinkPost = CreateGlobalForward("TF2_OnClientRegenThinkPost", ET_Ignore, Param_Cell, Param_Cell, Param_Float, Param_Cell);
}

public void OnMapStart() {
	if (!dt_CTFPlayer_RegenThink.Enable(Hook_Pre, RegenThinkHook))
		SetFailState("Could not hook CTFPlayer::RegenThink()");
}

public void OnMapEnd() {
	dt_CTFPlayer_RegenThink.Disable(Hook_Pre, RegenThinkHook);
}

static Action Call_RegenThinkPre(int client) {
	Call_StartForward(fwd_RegenThinkPre);
	Call_PushCell(client);
	Action result;
	if (Call_Finish(result) != SP_ERROR_NONE) {
		PrintToServer("[TF2 RegenThinkHook] Forwarding RegenThink-Pre failed");
	}
	return result;
}
static Action Call_RegenThinkHealth(int client, float& regenFromClass, float& regenFromAttribs) {
	Call_StartForward(fwd_RegenThinkHealth);
	Call_PushCell(client);
	Call_PushFloatRef(regenFromClass);
	Call_PushFloatRef(regenFromAttribs);
	Action result;
	if (Call_Finish(result) != SP_ERROR_NONE) {
		PrintToServer("[TF2 RegenThinkHook] Forwarding RegenThink-Health failed");
	}
	return result;
}
static Action Call_RegenThinkAmmo(int client, float& regenAmmoPercent, int& regenMetalAmount) {
	Call_StartForward(fwd_RegenThinkAmmo);
	Call_PushCell(client);
	Call_PushFloatRef(regenAmmoPercent);
	Call_PushCellRef(regenMetalAmount);
	Action result;
	if (Call_Finish(result) != SP_ERROR_NONE) {
		PrintToServer("[TF2 RegenThinkHook] Forwarding RegenThink-Ammo failed");
	}
	return result;
}
static void Call_RegenThinkPost(int client, int regenHealthAmount, float regenAmmoPercent, int regenMetalAmount) {
	Call_StartForward(fwd_RegenThinkPost);
	Call_PushCell(client);
	Call_PushCell(regenHealthAmount);
	Call_PushFloat(regenAmmoPercent);
	Call_PushCell(regenMetalAmount);
	if (Call_Finish() != SP_ERROR_NONE) {
		PrintToServer("[TF2 RegenThinkHook] Forwarding RegenThink-Post failed");
	}
}

public MRESReturn RegenThinkHook(int pThis) {
	RegenThinkOverride(pThis);
	return MRES_Supercede;
}

stock void ThinkSet(int entity, Address func, float nextCall = 0.0, const char[] context = "") {
	SDKCall(sc_CBaseEntity_ThinkSet, entity, func, nextCall, context);
}
stock int PlayerTakeHealth(int client, int health, int damage_flags) {
	return SDKCall(sc_CTFPlayer_TakeHealth, client, health, damage_flags);
}
stock void PlayerRegenAmmo(int client, int ammotype, float amount) {
	SDKCall(sc_CTFPlayer_RegenAmmo, client, ammotype, amount);
}

static float RemapRange(float value, float inMin, float inMax, float outMin, float outMax) {
	//normalize
	float normal = (value - inMin) / (inMax - inMin);
	//clamp
	if (normal < 0.0) normal = 0.0;
	else if (normal > 1.0) normal = 1.0;
	//rescale
	return normal * (outMax-outMin) + outMin;
}
static int GetMedicPatient(int medic) {
	int weapon = GetEntPropEnt(medic, Prop_Data, "m_hActiveWeapon");
	char clzname[64];
	if (weapon == INVALID_ENT_REFERENCE || !GetEdictClassname(weapon,clzname,sizeof(clzname)) || !StrEqual(clzname,"tf_weapon_medigun")) return -1;
	return GetEntPropEnt(weapon, Prop_Send, "m_hHealingTarget");
}
static int GetClientMaxHealth(int client) {
	return GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iMaxHealth", _, client);
}
static void RegenThinkOverride(int client) {
	if (!IsPlayerAlive(client)) return;
	ThinkSet(client, addr_CTFPlayer_RegenThink, GetGameTime()+TF_REGEN_THINK_INTERVAL, "RegenThink");
	if (GetGameTime() < GetEntDataFloat(client, off_CTFPlayer_m_flLastHealthRegenAt)+TF_REGEN_THINK_INTERVAL) return;
	
	if (Call_RegenThinkPre(client)>=Plugin_Handled) return;
	
	bool regenFx = true;
	float healthRegenAccu = GetEntDataFloat(client, off_CTFPlayer_m_flAccumulatedHealthRegen); //read back "left over" from last think
	float healthClass, healthAttribs;
	
	// medic health regen
	if (TF2_GetPlayerClass(client) == TFClass_Medic) {
		healthClass = TF_REGEN_HEALTH;
		
		int patient = GetMedicPatient(client);
		if (1<=patient<=MaxClients && GetClientHealth(client) < GetClientMaxHealth(client)) {
			//actively healing a patient, double healing
			healthClass += TF_REGEN_HEALTH;
		}
		
		//heal more if not taken damage for some time
		float timeSinceDmg = GetGameTime() - GetEntPropFloat(client, Prop_Data, "m_flLastDamageTime");
		healthClass *= RemapRange(timeSinceDmg, 5.0, 10.0, 1.0, 2.0);
		
		//healing_mastery attribute check
		if (GameRules_GetProp("m_bPlayingMannVsMachine")) {
			int healing_mastery = TF2Attrib_HookValueInt(0, "healing_mastery", client);
			if (healing_mastery) healthClass *= RemapRange(float(healing_mastery), 1.0, 4.0, 1.25, 2.0);
		}
		
		regenFx = false;
	}
	
	// process other attribs
	healthAttribs = TF2Attrib_HookValueFloat(0.0, "add_health_regen", client);
	if (healthAttribs && !GameRules_GetProp("m_bPlayingMannVsMachine")) {
		float timeSinceDmg = GetGameTime() - GetEntPropFloat(client, Prop_Data, "m_flLastDamageTime");
		if (timeSinceDmg < 5.0) healthAttribs *= 0.5;
		else if (timeSinceDmg < 10.0) healthAttribs *= (timeSinceDmg / 10.0);
	}
	
	if (Call_RegenThinkHealth(client, healthClass, healthAttribs) >= Plugin_Handled) {
		healthClass = healthAttribs = 0.0;
	} else {
		healthRegenAccu += healthClass + healthAttribs;
	}
	
	// apply accumulator
	int healedAmount;
	if (healthRegenAccu >= 1.0) {
		healedAmount = RoundToFloor(healthRegenAccu);
		if (GetClientHealth(client) < GetClientMaxHealth(client)) {
			int actualAmount = PlayerTakeHealth(client, healedAmount, DMG_SLASH);
			if (actualAmount) {
				Event event = CreateEvent("player_healed");
				if (event != INVALID_HANDLE) {
					event.SetInt("priority", 1);
					event.SetInt("patient", GetClientOfUserId(client));
					event.SetInt("healer", GetClientOfUserId(client));
					event.SetInt("amount", actualAmount);
					event.Fire();
				}
			}
		}
	} else if (healthRegenAccu <= -1.0) {
		healedAmount = RoundToCeil(healthRegenAccu);
		SDKHooks_TakeDamage(client, client, client, healedAmount*-1.0);
	}
	
	// play regen effect
	if (regenFx && healedAmount != 0 && GetClientHealth(client) < GetClientMaxHealth(client)) {
		Event event = CreateEvent("player_healonhit");
		if (event != INVALID_HANDLE) {
			event.SetInt("amount", healedAmount);
			event.SetInt("entindex", client);
			event.SetInt("weapon_def_index", -1);
			event.Fire();
		}
	}
	
	// adjust value storage
	healthRegenAccu -= float(healedAmount);
	SetEntDataFloat(client, off_CTFPlayer_m_flLastHealthRegenAt, GetGameTime());
	SetEntDataFloat(client, off_CTFPlayer_m_flAccumulatedHealthRegen, healthRegenAccu);
	
	// regenerate ammo and metal
	float ammoAmount;
	int metalAmount;
	if (GetGameTime() > GetEntDataFloat(client, off_CTFPlayer_m_flNextAmmoRegenAt)) {
		SetEntDataFloat(client, off_CTFPlayer_m_flNextAmmoRegenAt, GetGameTime()+TF_REGEN_AMMO_INTERVAL);
		
		ammoAmount = TF2Attrib_HookValueFloat(0.0, "addperc_ammo_regen", client);
		metalAmount = TF2Attrib_HookValueInt(0, "add_metal_regen", client);
		
		if (Call_RegenThinkAmmo(client, ammoAmount, metalAmount) >= Plugin_Handled) {
			ammoAmount = 0.0;
			metalAmount = 0;
		}
		
		if (ammoAmount) {
			PlayerRegenAmmo(client, 1, ammoAmount);
			PlayerRegenAmmo(client, 2, ammoAmount);
		}
		if (metalAmount) {
			GivePlayerAmmo(client, metalAmount, 3, true);
		}
	}
	
	Call_RegenThinkPost(client, healedAmount, ammoAmount, metalAmount);
}