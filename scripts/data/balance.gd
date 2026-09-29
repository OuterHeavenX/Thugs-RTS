class_name Balance
extends RefCounted

## Every cost, stat, and rate in one place.

const MAP_W := 24
const MAP_H := 24

const START_SUPPLIES := 250
const START_CASH := 100
const SUPPLY_NODES := 12
const CASH_NODES := 8
const NODE_SUPPLY_AMOUNT := 500
const NODE_CASH_AMOUNT := 300

const WORKER_COST_S := 50
const WORKER_COST_C := 0
const BARRACKS_COST_S := 150
const BARRACKS_COST_C := 50
const SOLDIER_COST_S := 75
const SOLDIER_COST_C := 25

const WORKER_HP := 60
const WORKER_SPEED := 4.2
const WORKER_DMG := 4
const WORKER_ATTACK_CD := 1.3
const SOLDIER_HP := 130
const SOLDIER_SPEED := 5.2
const SOLDIER_DMG := 14
const SOLDIER_AGGRO := 6.0

const ATTACK_RANGE := 1.0
const ATTACK_CD := 1.0
const CARRY_AMOUNT := 10
const HARVEST_TIME := 2.0
const UNIT_CAP := 24
const START_WORKERS := 3

const HQ_HP := 800
const BARRACKS_HP := 500
const BUILD_TIME := 15.0
const WORKER_TRAIN_TIME := 5.0
const SOLDIER_TRAIN_TIME := 8.0

const AI_TICK := 2.0
const AI_WORKERS := 5
const AI_SOLDIERS := 8
const AI_WAVE_SIZE := 6
