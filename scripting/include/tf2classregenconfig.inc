#if defined __tf2_class_regen_config_included
#endinput
#endif
#define __tf2_class_regen_config_included

#include <tf2>

/**
 * Structure used to configure how player or class regeneration is handled.
 * Priority is PlayerOverride, ClassOverride, Default ClassOverride, Internal Defaults.
 * Values are not inherited from a base, if you want a player override based on a class override,
 * get the class override, modify values and set it as player override.
 */
enum struct RegenOverrideParameters {
	/**
	 * Set to true to use this override
	 */
	bool active;
	/**
	 * The base health regeneration per tick (1sec). Decimals will accumulate
	 * until a whole HP can be given.
	 */
	float baseRegen;
	/**
	 * Base health increase for medics if they are currently healing a patient.
	 * Does not apply to other classes.
	 */
	float healingAdd;
	/**
	 * Parameter for the no-damage regen curve. Vanilla only used by Medic.
	 * The default curve medic uses: The scale is 1x to 2x from 5 seconds to 10
	 * seconds, multiplicative.
	 * This is the delay after the last damage taken before regenration STARTS
	 * to be changed.
	 */
	float noDamageStart;
	/**
	 * Parameter for the no-damage regen curve. Vanilla only used by Medic.
	 * The default curve medic uses: The scale is 1x to 2x from 5 seconds to 10
	 * seconds, multiplicative.
	 * This is the delay after the last damage taken after the change in 
	 * regenration PEAKS.
	 */
	float noDamageEnd;
	/**
	 * Parameter for the no-damage regen curve. Vanilla only used by Medic.
	 * The default curve medic uses: The scale is 1x to 2x from 5 seconds to 10 
	 * seconds, multiplicative.
	 * This is the scale value at the peak. The value will be scaled linear
	 * between noDamageStart and noDamageEnd. For multiplicative scaling the 
	 * initial value will always be 1x (baseRegen), for additive the initial 
	 * value will always be +0HP.
	 */
	float noDamageScale;
	/**
	 * Parameter for the no-damage regen curve. Vanilla only used by Medic.
	 * The default curve medic uses: The scale is 1x to 2x from 5 seconds to 10
	 * seconds, multiplicative.
	 * Set how the damage scaling is calculated, multiplicative values will take
	 * into account if the medic has a patient, additive will allway add the
	 * interpolated value flat.
	 * 
	 * Multiplicative: regen *= clamed remap of time-since-last-damage from
	 *     noDamageStart...noDamageEnd to 1.0-times...noDamageScale-times
	 * Additive: regen += clamed remap of time-since-last-damage from
	 *     noDamageStart...noDamageEnd to +0 HP...+noDamageScale HP
	 */
	bool noDamageAdd;
	/**
	 * This is a pretty basic way to prevent the Blutsauger from hurting medics 
	 * if the resulting regeneration + attribute regeneration is below +0 HP.
	 * If this is true, the regeneration will be set to 0 in this case.
	 */
	bool neverHurt;
	/**
	 * This will scale the ammount of ammo granted by the ammo regeneration tick
	 * every 5s seconds. To not change the value, set to 1.0.
	 */
	float ammoScale;
	/**
	 * Ammount of ammo to add on top of the attribute based generation every
	 * 5 seconds. This is a percentage value where 1.0 means +100% max ammo.
	 */
	float ammoAdd;
	/**
	 * This will scale the ammount of metal granted by the ammo regeneration tick
	 * every 5s seconds. To not change the value, set to 1.0.
	 * This value is only relevant for classes that use metal.
	 */
	float metalScale;
	/**
	 * Ammount of metal to add on top of the attribute based generation every
	 * 5 seconds. This is a plain amount of metal, remember 200 is the default max.
	 * This value is only relevant for classes that use metal.
	 */
	int metalAdd;
}

/**
 * Called after the config was parsed, if an admin hot-reloaded the config, this
 * will have replaced any plugin overrides previously set
 */
forward void TF2RegenConfig_OnConfigLoaded();

/**
 * Get the effective player regen override configuration.
 * Returns, in order:
 * - player override if set
 * - class override if set
 * - all-class override if set
 * - internal default values otherwise
 */
native void TF2RegenConfig_GetEffectiveOverride(int client, RegenOverrideParameters parameters);

/**
 * Get the player specific regen override.
 * @return true if the configuration is active.
 */
native bool TF2RegenConfig_GetPlayerOverride(int client, RegenOverrideParameters parameters);
/**
 * Set the player specific regen override.
 */
native void TF2RegenConfig_SetPlayerOverride(int client, RegenOverrideParameters parameters);
/**
 * Get the player specific regen override.
 * @param class - use TFClass_Unknown to access the all-class fallback values
 * @return true if the configuration is active.
 */
native bool TF2RegenConfig_GetClassOverride(TFClassType class, RegenOverrideParameters parameters);
/**
 * Set the player specific regen override.
 * @param class - use TFClass_Unknown to access the all-class fallback values
 */
native void TF2RegenConfig_SetClassOverride(TFClassType class, RegenOverrideParameters parameters);


public SharedPlugin __pl_tf2classregenconfig = {
	name = "tf2classregenconfig",
	file = "tf2classregenconfig.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};


#if !defined REQUIRE_PLUGIN
public void __pl_tf2classregenconfig_SetNTVOptional() {
}
#endif