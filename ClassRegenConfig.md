# TF2 Class Regen Config

Module plugin for TF2 RegenThink Hook.

Allows you to re-define health, ammo and metal regeneration for all classes using a config.

Plugins can use this as well to override the regeneration per class or player.

## Commands & ConVars

`sm_classregen_reloadconfig` - requires ADMFLAG_CONFIG, reload the config at `cfg/sourcemod/classregenconfig.cfg`

`sm_tf2classregenconfig_version` - version ConVar

## Config

The following config section will directly apply to classes:
* `scout`
* `sniper`
* `soldier`
* `demoman`
* `medic`
* `heavy`
* `pyro`
* `spy`
* `engineer`
* `#default` - Can be used to configure all classes that are not specified

You can also create sections with custom names to copy they values into class section, you can not copy copied sections.
To copy one sections into another, specify `"copy" "othersection"`. Other keys in the section will be ignored if copied.

KeyValues per config:

* `baseRegen` (number) - base health gain per second
* `healingAdd` (number) - additional health gain per second if the player is medic and has a patient
* `noDamageBoost` (section) - section that defines how health regen behaved if the player hasn't received damage for some time
  * `startAfterSec` (number) - start changeing health regen after this amount of seconds without taking damage
  * `scaleUntilSec` (number) - change peaks after this amount of seconds without taking damage
  * `maxScale` (number) - maximum change value after `scaleUntilSec`
  * `additive` (0/1) - defines how the scaling is applied. Multiplicative values will take into account if the medic has a patient, additive will allway add the interpolated value flat   
	Multiplicative (0): regen *= clamed remap of time-since-last-damage from noDamageStart...noDamageEnd to 1.0-times...noDamageScale-times   
	Additive (1): regen += clamed remap of time-since-last-damage from noDamageStart...noDamageEnd to +0 HP...+noDamageScale HP
* `neverHurt` (0/1) - if enabled, and the health regen including attributes would result in damaging the player, both values are reset to 0. This is a dirty fix for the blutsauger, you should probably use a CustomWeapons plugin instead.
* `ammo` (section) - configure ammo regeneration. Ammo regeneration will only tick every 5 seconds
  * `scaleAttributeValue` (number) - multiply the amount of ammo regeneration from item attribute by this value
  * `addRegenPrecent` (number) - add this amount of ammo on top of item attributes in percent. 100 = full ammo
* `metal` (section) - configure metal regeneration. This is run with ammo regeneration, but only interesting for engineer
  * `scaleAttributeValue` (number) - multiply the amount of metal regeneration from item attributes by this value
  * `addRegenAmount` (number) - plain amount of metal to add every tick on top of item attributes

Example Config:

```
"ClassRegenConfig"
{
	"Medic Like"
	{
		"baseRegen" "3.0"
		"noDamageBoost" 
		{
			"startAfterSec" "5.0"
			"scaleUntilSec" "10.0"
			"maxScale" "2.0"
			"additive" "0"
		}
	}
	
	"pyro"
	{
		"copy" "Medic Like"
	}
	
	"medic"
	{
		//disable medic health regen
		"baseRegen" "0.0"
		"healingAdds" "0.0" // healing a patient
		"neverHurt" "1" // cheap blutsuager fix
	}
}
```