extends RefCounted

const ICON_ROOT_SKILLS: String = "res://assets/raw/rts_icons/skills/"
const ICON_ROOT_UI: String = "res://assets/raw/rts_icons/ui_actions/"
const ICON_ROOT_BUILDINGS: String = "res://assets/raw/rts_icons/buildings/"
const ICON_TMP_BUILD: String = "res://icon_build_tmp.png"
const RTS_CONFIG_REGISTRY: Script = preload("res://scripts/core/config/rts_config_registry.gd")
const LEGACY_FALLBACK_SETTING_PATH: String = "application/config/rts_catalog_enable_legacy_fallback"
const LEGACY_FALLBACK_DEFAULT: bool = true

const UNIT_DEFS: Dictionary = {
	"worker": {
		"display_name": "Engineer",
		"role_tag": "ENG",
		"is_worker_role": true,
		"cost": 50,
		"gas_cost": 0,
		"supply": 1,
		"max_health": 65.0,
		"move_speed": 4.9,
		"gather_range": 1.8,
		"dropoff_range": 2.4,
		"carry_capacity": 6,
		"gather_amount": 5,
		"gather_interval": 1.45,
		"mining_search_radius": 36.0,
		"mining_nav_finish_contact_slack": 0.18,
		"mining_nav_finish_anchor_slack": 0.9,
		"interaction_fallbacks": {
			"gather": {
				"enable_nav_soft_contact": true,
				"contact_slack": 0.18,
				"enable_nav_anchor_fallback": true,
				"anchor_slack": 0.9,
				"enable_nav_reissue": true,
				"reissue_interval": 0.35
			},
			"dropoff": {
				"enable_nav_soft_contact": true,
				"contact_slack": 0.18,
				"enable_nav_anchor_fallback": true,
				"anchor_slack": 0.9,
				"enable_nav_reissue": true,
				"reissue_interval": 0.35
			},
			"repair": {
				"enable_nav_soft_contact": false,
				"contact_slack": 0.0,
				"enable_nav_anchor_fallback": false,
				"anchor_slack": 0.0,
				"enable_nav_reissue": true,
				"reissue_interval": 0.45
			}
		},
		"body_radius": 0.32,
		"nav_agent_radius": 0.3,
		"nav_agent_height": 1.0,
		"nav_avoidance_priority": 0.28,
		"push_priority": 1,
		"push_can_be_displaced": true,
		"attack_damage": 0.0,
		"attack_range": 0.0,
		"attack_cooldown": 0.0,
		"requires_buildings": ["base"],
		"requires_tech": [],
		"skills": ["move", "gather", "repair", "return_resource", "build_menu", "stop"],
		"build_skills": [
			"build_barracks",
			"build_supply_depot",
			"build_tower",
			"build_academy",
			"build_engineering_bay",
			"build_psionic_relay",
			"build_bio_vat",
			"build_warp_gate",
			"build_tech_lab",
			"build_void_core"
		]
	},
	"field_technician": {
		"display_name": "Field Technician",
		"role_tag": "TEC",
		"is_worker_role": true,
		"cost": 65,
		"gas_cost": 0,
		"supply": 1,
		"max_health": 72.0,
		"move_speed": 4.8,
		"gather_range": 1.9,
		"dropoff_range": 2.4,
		"carry_capacity": 6,
		"gather_amount": 5,
		"gather_interval": 1.4,
		"repair_amount": 16.0,
		"repair_interval": 0.46,
		"body_radius": 0.33,
		"nav_agent_radius": 0.31,
		"nav_agent_height": 1.0,
		"nav_avoidance_priority": 0.3,
		"push_priority": 1,
		"push_can_be_displaced": true,
		"attack_damage": 0.0,
		"attack_range": 0.0,
		"attack_cooldown": 0.0,
		"requires_buildings": ["base", "academy"],
		"requires_tech": ["field_logistics"],
		"skills": ["move", "gather", "repair", "return_resource", "stop"],
		"build_skills": []
	},
	"hauler_drone": {
		"display_name": "Hauler Drone",
		"role_tag": "HUL",
		"is_worker_role": true,
		"cost": 70,
		"gas_cost": 20,
		"supply": 1,
		"max_health": 80.0,
		"move_speed": 5.2,
		"gather_range": 1.8,
		"dropoff_range": 2.6,
		"carry_capacity": 12,
		"gather_amount": 6,
		"gather_interval": 1.7,
		"mining_search_radius": 42.0,
		"body_radius": 0.34,
		"nav_agent_radius": 0.32,
		"nav_agent_height": 1.0,
		"nav_avoidance_priority": 0.26,
		"push_priority": 1,
		"push_can_be_displaced": true,
		"attack_damage": 0.0,
		"attack_range": 0.0,
		"attack_cooldown": 0.0,
		"requires_buildings": ["base", "supply_depot"],
		"requires_tech": ["field_logistics"],
		"skills": ["move", "gather", "return_resource", "stop"],
		"build_skills": []
	},
	"soldier": {
		"display_name": "Rifleman",
		"role_tag": "RFL",
		"is_worker_role": false,
		"cost": 75,
		"gas_cost": 0,
		"supply": 1,
		"max_health": 105.0,
		"move_speed": 6.0,
		"body_radius": 0.42,
		"nav_agent_radius": 0.4,
		"nav_agent_height": 1.12,
		"nav_avoidance_priority": 0.82,
		"push_priority": 3,
		"push_can_be_displaced": false,
		"attack_damage": 12.0,
		"attack_range": 2.5,
		"attack_cooldown": 0.8,
		"requires_buildings": ["barracks"],
		"requires_tech": [],
		"skills": ["move", "attack", "stop"],
		"build_skills": []
	},
	"assault_trooper": {
		"display_name": "Assault Trooper",
		"role_tag": "AST",
		"is_worker_role": false,
		"cost": 95,
		"gas_cost": 15,
		"supply": 1,
		"max_health": 130.0,
		"move_speed": 5.8,
		"body_radius": 0.44,
		"nav_agent_radius": 0.42,
		"nav_agent_height": 1.12,
		"nav_avoidance_priority": 0.84,
		"push_priority": 3,
		"push_can_be_displaced": false,
		"attack_damage": 18.0,
		"attack_range": 1.95,
		"attack_cooldown": 1.0,
		"requires_buildings": ["barracks"],
		"requires_tech": ["infantry_weapons_1"],
		"skills": ["move", "attack", "stop"],
		"build_skills": []
	},
	"marksman": {
		"display_name": "Marksman",
		"role_tag": "MRK",
		"is_worker_role": false,
		"cost": 90,
		"gas_cost": 35,
		"supply": 1,
		"max_health": 95.0,
		"move_speed": 5.9,
		"body_radius": 0.4,
		"nav_agent_radius": 0.38,
		"nav_agent_height": 1.1,
		"nav_avoidance_priority": 0.8,
		"push_priority": 2,
		"push_can_be_displaced": false,
		"attack_damage": 22.0,
		"attack_range": 5.6,
		"attack_cooldown": 1.35,
		"requires_buildings": ["barracks", "academy"],
		"requires_tech": ["infantry_weapons_1"],
		"skills": ["move", "attack", "stop"],
		"build_skills": []
	},
	"heavy_gunner": {
		"display_name": "Heavy Gunner",
		"role_tag": "HVG",
		"is_worker_role": false,
		"cost": 125,
		"gas_cost": 55,
		"supply": 2,
		"max_health": 210.0,
		"move_speed": 4.6,
		"body_radius": 0.5,
		"nav_agent_radius": 0.48,
		"nav_agent_height": 1.24,
		"nav_avoidance_priority": 0.9,
		"push_priority": 4,
		"push_can_be_displaced": false,
		"attack_damage": 30.0,
		"attack_range": 3.1,
		"attack_cooldown": 1.2,
		"requires_buildings": ["bio_vat"],
		"requires_tech": ["heavy_plating"],
		"skills": ["move", "attack", "stop"],
		"build_skills": []
	},
	"rocket_trooper": {
		"display_name": "Rocket Trooper",
		"role_tag": "RKT",
		"is_worker_role": false,
		"cost": 115,
		"gas_cost": 70,
		"supply": 2,
		"max_health": 145.0,
		"move_speed": 5.1,
		"body_radius": 0.45,
		"nav_agent_radius": 0.43,
		"nav_agent_height": 1.16,
		"nav_avoidance_priority": 0.86,
		"push_priority": 3,
		"push_can_be_displaced": false,
		"attack_damage": 34.0,
		"attack_range": 4.5,
		"attack_cooldown": 1.35,
		"requires_buildings": ["bio_vat", "engineering_bay"],
		"requires_tech": ["mech_chassis"],
		"skills": ["move", "attack", "stop"],
		"build_skills": []
	},
	"scout_mech": {
		"display_name": "Scout Mech",
		"role_tag": "SCM",
		"is_worker_role": false,
		"cost": 120,
		"gas_cost": 90,
		"supply": 2,
		"max_health": 165.0,
		"move_speed": 6.8,
		"body_radius": 0.46,
		"nav_agent_radius": 0.44,
		"nav_agent_height": 1.2,
		"nav_avoidance_priority": 0.88,
		"push_priority": 4,
		"push_can_be_displaced": false,
		"attack_damage": 24.0,
		"attack_range": 3.8,
		"attack_cooldown": 0.75,
		"requires_buildings": ["warp_gate"],
		"requires_tech": ["mech_chassis"],
		"skills": ["move", "attack", "stop"],
		"build_skills": []
	},
	"siege_mech": {
		"display_name": "Siege Mech",
		"role_tag": "SGM",
		"is_worker_role": false,
		"cost": 170,
		"gas_cost": 130,
		"supply": 3,
		"max_health": 240.0,
		"move_speed": 4.3,
		"body_radius": 0.56,
		"nav_agent_radius": 0.52,
		"nav_agent_height": 1.3,
		"nav_avoidance_priority": 0.93,
		"push_priority": 5,
		"push_can_be_displaced": false,
		"attack_damage": 48.0,
		"attack_range": 6.4,
		"attack_cooldown": 1.55,
		"requires_buildings": ["warp_gate", "tech_lab"],
		"requires_tech": ["precision_targeting"],
		"skills": ["move", "attack", "stop"],
		"build_skills": []
	},
	"commando": {
		"display_name": "Command Operative",
		"role_tag": "CMD",
		"is_worker_role": false,
		"cost": 210,
		"gas_cost": 160,
		"supply": 3,
		"max_health": 260.0,
		"move_speed": 6.3,
		"body_radius": 0.48,
		"nav_agent_radius": 0.45,
		"nav_agent_height": 1.18,
		"nav_avoidance_priority": 0.95,
		"push_priority": 5,
		"push_can_be_displaced": false,
		"attack_damage": 42.0,
		"attack_range": 4.6,
		"attack_cooldown": 0.78,
		"requires_buildings": ["void_core"],
		"requires_tech": ["quantum_command"],
		"skills": ["move", "attack", "stop"],
		"build_skills": []
	}
}

const BUILDING_DEFS: Dictionary = {
	"base": {
		"display_name": "Command Base",
		"role_tag": "HQ",
		"construction_paradigm": "summoning",
		"build_time": 0.0,
		"cancel_refund_ratio": 0.75,
		"max_health": 1450.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": true,
		"can_queue_worker": true,
		"can_queue_soldier": false,
		"worker_build_time": 2.8,
		"soldier_build_time": 0.0,
		"trainable_units": {
			"worker": 2.8,
			"field_technician": 3.4,
			"hauler_drone": 3.8
		},
		"queue_limit": 8,
		"spawn_offset": Vector3(3.2, 0.0, 0.0),
		"requires_buildings": [],
		"requires_tech": [],
		"skills": ["train_worker", "train_field_technician", "train_hauler_drone", "build_menu"],
		"build_skills": [
			"build_barracks",
			"build_supply_depot",
			"build_tower",
			"build_academy",
			"build_engineering_bay",
			"build_psionic_relay",
			"build_bio_vat",
			"build_warp_gate",
			"build_tech_lab",
			"build_void_core"
		]
	},
	"barracks": {
		"display_name": "Barracks",
		"role_tag": "RAX",
		"cost": 165,
		"gas_cost": 0,
		"construction_paradigm": "garrisoned",
		"build_time": 6.2,
		"cancel_refund_ratio": 0.75,
		"max_health": 930.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": true,
		"worker_build_time": 0.0,
		"soldier_build_time": 4.0,
		"trainable_units": {
			"soldier": 4.0,
			"assault_trooper": 4.6,
			"marksman": 5.0
		},
		"queue_limit": 8,
		"spawn_offset": Vector3(3.6, 0.0, 0.0),
		"requires_buildings": ["base"],
		"requires_tech": [],
		"skills": ["train_soldier", "train_assault_trooper", "train_marksman"],
		"build_skills": []
	},
	"supply_depot": {
		"display_name": "Logistics Depot",
		"role_tag": "SUP",
		"cost": 105,
		"gas_cost": 0,
		"construction_paradigm": "garrisoned",
		"build_time": 4.6,
		"cancel_refund_ratio": 0.75,
		"max_health": 690.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": false,
		"worker_build_time": 0.0,
		"soldier_build_time": 0.0,
		"trainable_units": {},
		"queue_limit": 0,
		"spawn_offset": Vector3(2.6, 0.0, 0.0),
		"supply_bonus": 12,
		"requires_buildings": ["base"],
		"requires_tech": [],
		"skills": [],
		"build_skills": []
	},
	"tower": {
		"display_name": "Defense Tower",
		"role_tag": "TWR",
		"cost": 125,
		"gas_cost": 0,
		"construction_paradigm": "garrisoned",
		"build_time": 5.2,
		"cancel_refund_ratio": 0.75,
		"max_health": 720.0,
		"attack_range": 9.2,
		"attack_damage": 15.0,
		"attack_cooldown": 0.9,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": false,
		"worker_build_time": 0.0,
		"soldier_build_time": 0.0,
		"trainable_units": {},
		"queue_limit": 0,
		"spawn_offset": Vector3(2.8, 0.0, 0.0),
		"requires_buildings": ["base", "supply_depot"],
		"requires_tech": [],
		"skills": [],
		"build_skills": []
	},
	"academy": {
		"display_name": "Tactics Academy",
		"role_tag": "ACD",
		"cost": 165,
		"gas_cost": 0,
		"construction_paradigm": "garrisoned",
		"build_time": 6.8,
		"cancel_refund_ratio": 0.75,
		"max_health": 810.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": false,
		"worker_build_time": 0.0,
		"soldier_build_time": 0.0,
		"trainable_units": {},
		"queue_limit": 6,
		"spawn_offset": Vector3(2.8, 0.0, 0.0),
		"requires_buildings": ["base", "barracks"],
		"requires_tech": [],
		"skills": ["research_infantry_weapons_1", "research_infantry_armor_1", "research_field_logistics"],
		"build_skills": []
	},
	"engineering_bay": {
		"display_name": "Engineering Bay",
		"role_tag": "ENG",
		"cost": 185,
		"gas_cost": 0,
		"construction_paradigm": "garrisoned",
		"build_time": 7.2,
		"cancel_refund_ratio": 0.75,
		"max_health": 840.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": false,
		"worker_build_time": 0.0,
		"soldier_build_time": 0.0,
		"trainable_units": {},
		"queue_limit": 6,
		"spawn_offset": Vector3(2.8, 0.0, 0.0),
		"requires_buildings": ["base", "academy", "supply_depot"],
		"requires_tech": [],
		"skills": ["research_mech_chassis", "research_heavy_plating"],
		"build_skills": []
	},
	"psionic_relay": {
		"display_name": "Support Relay",
		"role_tag": "SUPR",
		"cost": 150,
		"gas_cost": 0,
		"construction_paradigm": "summoning",
		"build_time": 6.0,
		"cancel_refund_ratio": 0.75,
		"max_health": 650.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": false,
		"worker_build_time": 0.0,
		"soldier_build_time": 0.0,
		"trainable_units": {},
		"queue_limit": 4,
		"spawn_offset": Vector3(2.6, 0.0, 0.0),
		"requires_buildings": ["base", "academy"],
		"requires_tech": ["field_logistics"],
		"skills": ["research_support_protocols"],
		"build_skills": []
	},
	"bio_vat": {
		"display_name": "Bio Vat",
		"role_tag": "BIO",
		"cost": 185,
		"gas_cost": 0,
		"construction_paradigm": "incorporated",
		"build_time": 7.4,
		"cancel_refund_ratio": 0.75,
		"max_health": 760.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": true,
		"worker_build_time": 0.0,
		"soldier_build_time": 4.8,
		"trainable_units": {
			"heavy_gunner": 5.6,
			"rocket_trooper": 5.4
		},
		"queue_limit": 6,
		"spawn_offset": Vector3(2.7, 0.0, 0.0),
		"requires_buildings": ["base", "engineering_bay", "psionic_relay"],
		"requires_tech": [],
		"skills": ["train_heavy_gunner", "train_rocket_trooper"],
		"build_skills": []
	},
	"warp_gate": {
		"display_name": "Warp Gate",
		"role_tag": "WRP",
		"cost": 210,
		"gas_cost": 0,
		"construction_paradigm": "summoning",
		"build_time": 8.4,
		"cancel_refund_ratio": 0.75,
		"max_health": 790.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": true,
		"worker_build_time": 0.0,
		"soldier_build_time": 4.6,
		"trainable_units": {
			"scout_mech": 5.5,
			"siege_mech": 7.0
		},
		"queue_limit": 6,
		"spawn_offset": Vector3(2.8, 0.0, 0.0),
		"requires_buildings": ["base", "engineering_bay"],
		"requires_tech": ["mech_chassis"],
		"skills": ["train_scout_mech", "train_siege_mech"],
		"build_skills": []
	},
	"tech_lab": {
		"display_name": "Tech Lab",
		"role_tag": "LAB",
		"cost": 230,
		"gas_cost": 0,
		"construction_paradigm": "incorporated",
		"build_time": 7.8,
		"cancel_refund_ratio": 0.75,
		"max_health": 890.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": false,
		"worker_build_time": 0.0,
		"soldier_build_time": 0.0,
		"trainable_units": {},
		"queue_limit": 6,
		"spawn_offset": Vector3(2.8, 0.0, 0.0),
		"requires_buildings": ["base", "engineering_bay"],
		"requires_tech": ["field_logistics"],
		"skills": ["research_infantry_weapons_2", "research_infantry_armor_2", "research_precision_targeting"],
		"build_skills": []
	},
	"void_core": {
		"display_name": "Void Core",
		"role_tag": "CORE",
		"cost": 260,
		"gas_cost": 0,
		"construction_paradigm": "incorporated",
		"build_time": 9.0,
		"cancel_refund_ratio": 0.75,
		"max_health": 940.0,
		"attack_range": 0.0,
		"attack_damage": 0.0,
		"attack_cooldown": 1.0,
		"is_resource_dropoff": false,
		"can_queue_worker": false,
		"can_queue_soldier": true,
		"worker_build_time": 0.0,
		"soldier_build_time": 6.8,
		"trainable_units": {
			"commando": 8.4
		},
		"queue_limit": 6,
		"spawn_offset": Vector3(2.9, 0.0, 0.0),
		"requires_buildings": ["base", "tech_lab", "warp_gate", "bio_vat"],
		"requires_tech": ["precision_targeting", "heavy_plating"],
		"skills": ["train_commando", "research_quantum_command"],
		"build_skills": []
	}
}

const TECH_DEFS: Dictionary = {
	"infantry_weapons_1": {
		"display_name": "Infantry Weapons I",
		"description": "Unlocks stronger rifle and assault payloads.",
		"cost": 120,
		"gas_cost": 0,
		"research_time": 8.0,
		"requires_buildings": ["academy"],
		"requires_tech": []
	},
	"infantry_armor_1": {
		"display_name": "Infantry Armor I",
		"description": "Reinforced vests for frontline infantry.",
		"cost": 110,
		"gas_cost": 0,
		"research_time": 8.0,
		"requires_buildings": ["academy"],
		"requires_tech": []
	},
	"field_logistics": {
		"display_name": "Field Logistics",
		"description": "Improves supply flow and unlocks support branches.",
		"cost": 140,
		"gas_cost": 40,
		"research_time": 10.0,
		"requires_buildings": ["academy"],
		"requires_tech": []
	},
	"mech_chassis": {
		"display_name": "Mech Chassis",
		"description": "Enables mech frame production.",
		"cost": 160,
		"gas_cost": 90,
		"research_time": 11.0,
		"requires_buildings": ["engineering_bay"],
		"requires_tech": ["field_logistics"]
	},
	"heavy_plating": {
		"display_name": "Heavy Plating",
		"description": "Unlocks heavy assault bio variants.",
		"cost": 190,
		"gas_cost": 110,
		"research_time": 12.0,
		"requires_buildings": ["engineering_bay"],
		"requires_tech": ["infantry_armor_1"]
	},
	"support_protocols": {
		"display_name": "Support Protocols",
		"description": "Advanced relay doctrine for sustained engagements.",
		"cost": 130,
		"gas_cost": 75,
		"research_time": 10.5,
		"requires_buildings": ["psionic_relay"],
		"requires_tech": ["field_logistics"]
	},
	"infantry_weapons_2": {
		"display_name": "Infantry Weapons II",
		"description": "High-caliber tactical package.",
		"cost": 180,
		"gas_cost": 70,
		"research_time": 12.0,
		"requires_buildings": ["tech_lab"],
		"requires_tech": ["infantry_weapons_1"]
	},
	"infantry_armor_2": {
		"display_name": "Infantry Armor II",
		"description": "Composite armor systems for elite squads.",
		"cost": 170,
		"gas_cost": 70,
		"research_time": 12.0,
		"requires_buildings": ["tech_lab"],
		"requires_tech": ["infantry_armor_1"]
	},
	"precision_targeting": {
		"display_name": "Precision Targeting",
		"description": "Siege and command units gain lock-on suites.",
		"cost": 210,
		"gas_cost": 130,
		"research_time": 13.0,
		"requires_buildings": ["tech_lab"],
		"requires_tech": ["infantry_weapons_2", "field_logistics"]
	},
	"quantum_command": {
		"display_name": "Quantum Command",
		"description": "Final doctrine unlock for command operatives.",
		"cost": 260,
		"gas_cost": 180,
		"research_time": 15.0,
		"requires_buildings": ["void_core"],
		"requires_tech": ["precision_targeting", "heavy_plating"]
	}
}

const DEFAULT_UNLOCKED_TECHS: Array[String] = []

const SKILL_DEFS: Dictionary = {
	"move": {
		"id": "move",
		"label": "Move",
		"icon_path": ICON_ROOT_SKILLS + "cmd_move.png",
		"hotkey": "RMB",
		"target_mode": "ground"
	},
	"attack": {
		"id": "attack",
		"label": "Attack",
		"icon_path": ICON_ROOT_SKILLS + "cmd_attack.png",
		"hotkey": "A",
		"target_mode": "unit_or_building"
	},
	"stop": {
		"id": "stop",
		"label": "Stop",
		"icon_path": ICON_ROOT_SKILLS + "cmd_stop.png",
		"hotkey": "S",
		"target_mode": "none"
	},
	"gather": {
		"id": "gather",
		"label": "Gather",
		"icon_path": ICON_ROOT_SKILLS + "cmd_gather.png",
		"hotkey": "",
		"target_mode": "resource",
		"queue_idle_dispatch": true
	},
	"repair": {
		"id": "repair",
		"label": "Repair",
		"icon_path": ICON_ROOT_SKILLS + "cmd_build.png",
		"hotkey": "",
		"target_mode": "friendly_building",
		"description": "Repair a damaged friendly building.",
		"queue_idle_dispatch": true
	},
	"return_resource": {
		"id": "return_resource",
		"label": "Return",
		"icon_path": ICON_ROOT_SKILLS + "cmd_return.png",
		"hotkey": "",
		"target_mode": "none",
		"queue_idle_dispatch": true
	},
	"build_menu": {
		"id": "build_menu",
		"label": "Build",
		"icon_path": ICON_ROOT_SKILLS + "cmd_build.png",
		"hotkey": "B",
		"target_mode": "none",
		"description": "Open categorized structure menus."
	},
	"build_menu_garrisoned": {
		"id": "build_menu_garrisoned",
		"label": "Garrisoned",
		"icon_path": ICON_ROOT_SKILLS + "cmd_build.png",
		"hotkey": "Q",
		"target_mode": "none",
		"description": "Show garrisoned construction structures."
	},
	"build_menu_summoning": {
		"id": "build_menu_summoning",
		"label": "Summoning",
		"icon_path": ICON_ROOT_SKILLS + "cmd_build.png",
		"hotkey": "W",
		"target_mode": "none",
		"description": "Show summoning construction structures."
	},
	"build_menu_incorporated": {
		"id": "build_menu_incorporated",
		"label": "Incorporated",
		"icon_path": ICON_ROOT_SKILLS + "cmd_build.png",
		"hotkey": "E",
		"target_mode": "none",
		"description": "Show incorporated (sacrifice) structures."
	},
	"build_menu_back": {
		"id": "build_menu_back",
		"label": "Back",
		"icon_path": ICON_ROOT_UI + "ui_close_back.png",
		"hotkey": "ESC",
		"target_mode": "none",
		"description": "Back to build categories."
	},
	"build_barracks": {
		"id": "build_barracks",
		"label": "Barracks",
		"icon_path": ICON_ROOT_BUILDINGS + "building_barracks.png",
		"hotkey": "Q",
		"target_mode": "placement",
		"building_kind": "barracks",
		"queue_idle_dispatch": true
	},
	"build_supply_depot": {
		"id": "build_supply_depot",
		"label": "Logistics Depot",
		"icon_path": ICON_TMP_BUILD,
		"hotkey": "G",
		"target_mode": "placement",
		"building_kind": "supply_depot",
		"queue_idle_dispatch": true
	},
	"build_tower": {
		"id": "build_tower",
		"label": "Defense Tower",
		"icon_path": ICON_ROOT_BUILDINGS + "building_tower.png",
		"hotkey": "W",
		"target_mode": "placement",
		"building_kind": "tower",
		"queue_idle_dispatch": true
	},
	"build_academy": {
		"id": "build_academy",
		"label": "Academy",
		"icon_path": ICON_TMP_BUILD,
		"hotkey": "E",
		"target_mode": "placement",
		"building_kind": "academy",
		"queue_idle_dispatch": true
	},
	"build_engineering_bay": {
		"id": "build_engineering_bay",
		"label": "Eng Bay",
		"icon_path": ICON_TMP_BUILD,
		"hotkey": "D",
		"target_mode": "placement",
		"building_kind": "engineering_bay",
		"queue_idle_dispatch": true
	},
	"build_tech_lab": {
		"id": "build_tech_lab",
		"label": "Tech Lab",
		"icon_path": ICON_TMP_BUILD,
		"hotkey": "C",
		"target_mode": "placement",
		"building_kind": "tech_lab",
		"queue_idle_dispatch": true
	},
	"build_warp_gate": {
		"id": "build_warp_gate",
		"label": "Warp Gate",
		"icon_path": ICON_TMP_BUILD,
		"hotkey": "F",
		"target_mode": "placement",
		"building_kind": "warp_gate",
		"queue_idle_dispatch": true
	},
	"build_psionic_relay": {
		"id": "build_psionic_relay",
		"label": "Support Relay",
		"icon_path": ICON_TMP_BUILD,
		"hotkey": "Z",
		"target_mode": "placement",
		"building_kind": "psionic_relay",
		"queue_idle_dispatch": true
	},
	"build_bio_vat": {
		"id": "build_bio_vat",
		"label": "Bio Vat",
		"icon_path": ICON_TMP_BUILD,
		"hotkey": "X",
		"target_mode": "placement",
		"building_kind": "bio_vat",
		"queue_idle_dispatch": true
	},
	"build_void_core": {
		"id": "build_void_core",
		"label": "Void Core",
		"icon_path": ICON_TMP_BUILD,
		"hotkey": "V",
		"target_mode": "placement",
		"building_kind": "void_core",
		"queue_idle_dispatch": true
	},
	"close_menu": {
		"id": "close_menu",
		"label": "Back",
		"icon_path": ICON_ROOT_UI + "ui_close_back.png",
		"hotkey": "ESC",
		"target_mode": "none"
	},
	"placement_confirm": {
		"id": "placement_confirm",
		"label": "Confirm Build",
		"icon_path": ICON_ROOT_SKILLS + "cmd_build.png",
		"hotkey": "LMB",
		"target_mode": "none"
	},
	"placement_rotate": {
		"id": "placement_rotate",
		"label": "Rotate",
		"icon_path": ICON_ROOT_UI + "ui_hold.png",
		"hotkey": "R",
		"target_mode": "none"
	},
	"placement_cancel": {
		"id": "placement_cancel",
		"label": "Cancel",
		"icon_path": ICON_ROOT_UI + "ui_close_back.png",
		"hotkey": "ESC",
		"target_mode": "none"
	},
	"construction_exit": {
		"id": "construction_exit",
		"label": "Exit Build",
		"icon_path": ICON_ROOT_UI + "ui_close_back.png",
		"hotkey": "ESC",
		"target_mode": "none"
	},
	"construction_cancel_destroy": {
		"id": "construction_cancel_destroy",
		"label": "Cancel+Destroy",
		"icon_path": ICON_ROOT_UI + "ui_close_back.png",
		"hotkey": "",
		"target_mode": "none"
	},
	"construction_select_worker": {
		"id": "construction_select_worker",
		"label": "Select Worker",
		"icon_path": ICON_ROOT_SKILLS + "cmd_move.png",
		"hotkey": "",
		"target_mode": "none"
	},
	"construction_cancel_eject": {
		"id": "construction_cancel_eject",
		"label": "Cancel+Eject",
		"icon_path": ICON_ROOT_UI + "ui_close_back.png",
		"hotkey": "",
		"target_mode": "none"
	},
	"train_worker": {
		"id": "train_worker",
		"label": "Engineer",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "R",
		"target_mode": "none",
		"unit_kind": "worker"
	},
	"train_field_technician": {
		"id": "train_field_technician",
		"label": "Field Technician",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "Y",
		"target_mode": "none",
		"unit_kind": "field_technician"
	},
	"train_hauler_drone": {
		"id": "train_hauler_drone",
		"label": "Hauler Drone",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "U",
		"target_mode": "none",
		"unit_kind": "hauler_drone"
	},
	"train_soldier": {
		"id": "train_soldier",
		"label": "Rifleman",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "T",
		"target_mode": "none",
		"unit_kind": "soldier"
	},
	"train_assault_trooper": {
		"id": "train_assault_trooper",
		"label": "Assault Trooper",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "F",
		"target_mode": "none",
		"unit_kind": "assault_trooper"
	},
	"train_marksman": {
		"id": "train_marksman",
		"label": "Marksman",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "G",
		"target_mode": "none",
		"unit_kind": "marksman"
	},
	"train_heavy_gunner": {
		"id": "train_heavy_gunner",
		"label": "Heavy Gunner",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "H",
		"target_mode": "none",
		"unit_kind": "heavy_gunner"
	},
	"train_rocket_trooper": {
		"id": "train_rocket_trooper",
		"label": "Rocket Trooper",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "J",
		"target_mode": "none",
		"unit_kind": "rocket_trooper"
	},
	"train_scout_mech": {
		"id": "train_scout_mech",
		"label": "Scout Mech",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "Q",
		"target_mode": "none",
		"unit_kind": "scout_mech"
	},
	"train_siege_mech": {
		"id": "train_siege_mech",
		"label": "Siege Mech",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "W",
		"target_mode": "none",
		"unit_kind": "siege_mech"
	},
	"train_commando": {
		"id": "train_commando",
		"label": "Commando",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "C",
		"target_mode": "none",
		"unit_kind": "commando"
	},
	"research_infantry_weapons_1": {
		"id": "research_infantry_weapons_1",
		"label": "Weapons I",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "Z",
		"target_mode": "none",
		"tech_id": "infantry_weapons_1"
	},
	"research_infantry_armor_1": {
		"id": "research_infantry_armor_1",
		"label": "Armor I",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "X",
		"target_mode": "none",
		"tech_id": "infantry_armor_1"
	},
	"research_field_logistics": {
		"id": "research_field_logistics",
		"label": "Field Logistics",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "V",
		"target_mode": "none",
		"tech_id": "field_logistics"
	},
	"research_mech_chassis": {
		"id": "research_mech_chassis",
		"label": "Mech Chassis",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "M",
		"target_mode": "none",
		"tech_id": "mech_chassis"
	},
	"research_heavy_plating": {
		"id": "research_heavy_plating",
		"label": "Heavy Plating",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "N",
		"target_mode": "none",
		"tech_id": "heavy_plating"
	},
	"research_support_protocols": {
		"id": "research_support_protocols",
		"label": "Support Protocols",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "B",
		"target_mode": "none",
		"tech_id": "support_protocols"
	},
	"research_infantry_weapons_2": {
		"id": "research_infantry_weapons_2",
		"label": "Weapons II",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "E",
		"target_mode": "none",
		"tech_id": "infantry_weapons_2"
	},
	"research_infantry_armor_2": {
		"id": "research_infantry_armor_2",
		"label": "Armor II",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "R",
		"target_mode": "none",
		"tech_id": "infantry_armor_2"
	},
	"research_precision_targeting": {
		"id": "research_precision_targeting",
		"label": "Precision Targeting",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "P",
		"target_mode": "none",
		"tech_id": "precision_targeting"
	},
	"research_quantum_command": {
		"id": "research_quantum_command",
		"label": "Quantum Command",
		"icon_path": ICON_ROOT_SKILLS + "cmd_train.png",
		"hotkey": "L",
		"target_mode": "none",
		"tech_id": "quantum_command"
	},
	"menu": {
		"id": "menu",
		"label": "Menu",
		"icon_path": ICON_ROOT_UI + "ui_hold.png",
		"hotkey": "F10",
		"target_mode": "none"
	}
}

const MATCH_SETTINGS: Dictionary = {
	"rule_check_interval": 0.25,
	"notify_only": true
}

const MATCH_RULE_DEFS: Array[Dictionary] = [
	{
		"id": "player_defeat_base_lost",
		"watch_group": "selectable_building",
		"team_id": 1,
		"building_kind": "base",
		"trigger_at_or_below": 0,
		"notice": "[DEFEAT] Main Base destroyed (test notice)."
	},
	{
		"id": "player_victory_enemy_core_lost",
		"watch_group": "selectable_building",
		"team_id": 2,
		"building_kind": "barracks",
		"trigger_at_or_below": 0,
		"notice": "[VICTORY] Enemy core destroyed (test notice)."
	}
]

static func get_unit_def(unit_kind: String) -> Dictionary:
	var registry_def: Dictionary = RTS_CONFIG_REGISTRY.get_unit_def(unit_kind)
	if not registry_def.is_empty():
		return _localize_dict_fields(registry_def, ["display_name"])
	if not is_legacy_fallback_enabled():
		return {}
	var value: Variant = UNIT_DEFS.get(unit_kind, {})
	if value is Dictionary:
		return _localize_dict_fields((value as Dictionary).duplicate(true), ["display_name"])
	return {}

static func get_building_def(building_kind: String) -> Dictionary:
	var registry_def: Dictionary = RTS_CONFIG_REGISTRY.get_building_def(building_kind)
	if not registry_def.is_empty():
		return _localize_dict_fields(registry_def, ["display_name"])
	if not is_legacy_fallback_enabled():
		return {}
	var value: Variant = BUILDING_DEFS.get(building_kind, {})
	if value is Dictionary:
		return _localize_dict_fields((value as Dictionary).duplicate(true), ["display_name"])
	return {}

static func get_unit_skill_ids(unit_kind: String) -> Array[String]:
	var unit_def: Dictionary = get_unit_def(unit_kind)
	return _normalize_skill_ids(unit_def.get("skills", []))

static func get_building_skill_ids(building_kind: String) -> Array[String]:
	var building_def: Dictionary = get_building_def(building_kind)
	return _normalize_skill_ids(building_def.get("skills", []))

static func get_unit_build_skill_ids(unit_kind: String) -> Array[String]:
	var unit_def: Dictionary = get_unit_def(unit_kind)
	return _normalize_skill_ids(unit_def.get("build_skills", []))

static func get_building_build_skill_ids(building_kind: String) -> Array[String]:
	var building_def: Dictionary = get_building_def(building_kind)
	return _normalize_skill_ids(building_def.get("build_skills", []))

static func get_unit_requires_buildings(unit_kind: String) -> Array[Dictionary]:
	var unit_def: Dictionary = get_unit_def(unit_kind)
	return _normalize_building_requirements(unit_def.get("requires_buildings", []))

static func get_unit_requires_tech(unit_kind: String) -> Array[String]:
	var unit_def: Dictionary = get_unit_def(unit_kind)
	return _normalize_tech_ids(unit_def.get("requires_tech", []))

static func get_building_requires_buildings(building_kind: String) -> Array[Dictionary]:
	var building_def: Dictionary = get_building_def(building_kind)
	return _normalize_building_requirements(building_def.get("requires_buildings", []))

static func get_building_requires_tech(building_kind: String) -> Array[String]:
	var building_def: Dictionary = get_building_def(building_kind)
	return _normalize_tech_ids(building_def.get("requires_tech", []))

static func get_unit_cost(unit_kind: String) -> int:
	var unit_def: Dictionary = get_unit_def(unit_kind)
	return maxi(0, int(unit_def.get("cost", 0)))

static func get_unit_gas_cost(unit_kind: String) -> int:
	var unit_def: Dictionary = get_unit_def(unit_kind)
	return maxi(0, int(unit_def.get("gas_cost", 0)))

static func get_unit_costs(unit_kind: String) -> Dictionary:
	return {
		"minerals": get_unit_cost(unit_kind),
		"gas": get_unit_gas_cost(unit_kind)
	}

static func get_building_cost(building_kind: String) -> int:
	var building_def: Dictionary = get_building_def(building_kind)
	return maxi(0, int(building_def.get("cost", 0)))

static func get_building_gas_cost(building_kind: String) -> int:
	var building_def: Dictionary = get_building_def(building_kind)
	return maxi(0, int(building_def.get("gas_cost", 0)))

static func get_building_costs(building_kind: String) -> Dictionary:
	return {
		"minerals": get_building_cost(building_kind),
		"gas": get_building_gas_cost(building_kind)
	}

static func get_tech_def(tech_id: String) -> Dictionary:
	var registry_def: Dictionary = RTS_CONFIG_REGISTRY.get_tech_def(tech_id)
	if not registry_def.is_empty():
		return _localize_dict_fields(registry_def, ["display_name", "description"])
	if not is_legacy_fallback_enabled():
		return {}
	var value: Variant = TECH_DEFS.get(tech_id, {})
	if value is Dictionary:
		return _localize_dict_fields((value as Dictionary).duplicate(true), ["display_name", "description"])
	return {}

static func get_tech_cost(tech_id: String) -> int:
	var tech_def: Dictionary = get_tech_def(tech_id)
	return maxi(0, int(tech_def.get("cost", 0)))

static func get_tech_gas_cost(tech_id: String) -> int:
	var tech_def: Dictionary = get_tech_def(tech_id)
	return maxi(0, int(tech_def.get("gas_cost", 0)))

static func get_tech_costs(tech_id: String) -> Dictionary:
	return {
		"minerals": get_tech_cost(tech_id),
		"gas": get_tech_gas_cost(tech_id)
	}

static func get_tech_research_time(tech_id: String) -> float:
	var tech_def: Dictionary = get_tech_def(tech_id)
	return maxf(0.0, float(tech_def.get("research_time", 0.0)))

static func get_tech_requires_buildings(tech_id: String) -> Array[Dictionary]:
	var tech_def: Dictionary = get_tech_def(tech_id)
	return _normalize_building_requirements(tech_def.get("requires_buildings", []))

static func get_tech_requires_tech(tech_id: String) -> Array[String]:
	var tech_def: Dictionary = get_tech_def(tech_id)
	return _normalize_tech_ids(tech_def.get("requires_tech", []))

static func get_default_unlocked_techs() -> Array[String]:
	return _normalize_tech_ids(DEFAULT_UNLOCKED_TECHS)

static func get_match_settings() -> Dictionary:
	return MATCH_SETTINGS.duplicate(true)

static func get_match_rule_defs() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rule_value in MATCH_RULE_DEFS:
		if rule_value is Dictionary:
			result.append(_localize_dict_fields((rule_value as Dictionary).duplicate(true), ["notice"]))
	return result

static func get_skill_def(skill_id: String) -> Dictionary:
	var registry_def: Dictionary = RTS_CONFIG_REGISTRY.get_skill_def(skill_id)
	if not registry_def.is_empty():
		return _localize_dict_fields(registry_def, ["label", "description"])
	if not is_legacy_fallback_enabled():
		return {}
	var value: Variant = SKILL_DEFS.get(skill_id, {})
	if value is Dictionary:
		return _localize_dict_fields((value as Dictionary).duplicate(true), ["label", "description"])
	return {}

static func is_legacy_fallback_enabled() -> bool:
	if ProjectSettings.has_setting(LEGACY_FALLBACK_SETTING_PATH):
		return bool(ProjectSettings.get_setting(LEGACY_FALLBACK_SETTING_PATH))
	return LEGACY_FALLBACK_DEFAULT

static func make_command_entry(skill_id: String, overrides: Dictionary = {}) -> Dictionary:
	var entry: Dictionary = get_skill_def(skill_id)
	if entry.is_empty():
		entry = {
			"id": skill_id,
			"label": _translate_text(skill_id.capitalize()),
			"icon_path": "",
			"hotkey": "",
			"target_mode": "none"
		}
	for key in overrides.keys():
		entry[key] = overrides[key]
	if not entry.has("id"):
		entry["id"] = skill_id
	if not entry.has("enabled"):
		entry["enabled"] = true
	return entry

static func get_build_kind_from_skill(skill_id: String) -> String:
	var skill_def: Dictionary = get_skill_def(skill_id)
	return str(skill_def.get("building_kind", ""))

static func get_tech_id_from_skill(skill_id: String) -> String:
	var skill_def: Dictionary = get_skill_def(skill_id)
	return str(skill_def.get("tech_id", ""))

static func get_unit_kind_from_skill(skill_id: String) -> String:
	var skill_def: Dictionary = get_skill_def(skill_id)
	return str(skill_def.get("unit_kind", ""))

static func _normalize_skill_ids(raw_value: Variant) -> Array[String]:
	var skill_ids: Array[String] = []
	if raw_value is Array:
		for value in raw_value:
			var skill_id: String = str(value)
			if skill_id == "":
				continue
			skill_ids.append(skill_id)
	return skill_ids

static func _normalize_tech_ids(raw_value: Variant) -> Array[String]:
	var tech_ids: Array[String] = []
	if raw_value is Array:
		for value in raw_value:
			var tech_id: String = str(value).strip_edges()
			if tech_id == "":
				continue
			tech_ids.append(tech_id)
	return tech_ids

static func _normalize_building_requirements(raw_value: Variant) -> Array[Dictionary]:
	var requirements: Array[Dictionary] = []
	if not (raw_value is Array):
		return requirements
	for raw_item in raw_value:
		var kind: String = ""
		var required_count: int = 1
		if raw_item is Dictionary:
			var item: Dictionary = raw_item as Dictionary
			kind = str(item.get("kind", item.get("building_kind", ""))).strip_edges()
			required_count = maxi(1, int(item.get("count", item.get("required_count", 1))))
		else:
			kind = str(raw_item).strip_edges()
		if kind == "":
			continue
		requirements.append({
			"kind": kind,
			"count": required_count
		})
	return requirements

static func _localize_dict_fields(source: Dictionary, fields: Array[String]) -> Dictionary:
	for field in fields:
		if not source.has(field):
			continue
		source[field] = _translate_text(str(source.get(field, "")))
	return source

static func _translate_text(message: String) -> String:
	if message == "":
		return ""
	return TranslationServer.translate(message)
