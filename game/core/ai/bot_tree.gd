extends RefCounted
## Builds the player bots' LimboAI behavior tree. tools/generators/bot_tree.gd saves it to
## game/data/bot_behavior.tres, which the game loads and which you can open and edit in the
## LimboAI editor; this builder is the fallback when that file is missing.
##
##   Selector
##     Sequence: IsStance dummy                 (dummies do nothing)
##     Sequence
##       UseSpellsAndPotions                    (heal, potions, attack spells)
##       Selector
##         Sequence: PickTarget, EngageTarget   (fight)
##         CollectLoot                          (stacks the bot's group earned nearby)
##         SellLoot                             (a selling trip once the packs are nearly full)
##         FollowLeader                         (companions, rival band members)
##         Sequence: IsStance rival, RunErrand  (rival band leaders: tasks, hunts, ambushes)
##         Sequence: AwayFromPost > 2, WalkToPost
##
## Blackboard (set at run time): "target" (int), the creature the bot fights.

const UseResources = preload("res://game/core/ai/tasks/bt_use_resources.gd")
const IsStance = preload("res://game/core/ai/tasks/bt_is_stance.gd")
const PickTarget = preload("res://game/core/ai/tasks/bt_pick_target.gd")
const Engage = preload("res://game/core/ai/tasks/bt_engage.gd")
const AwayFromPost = preload("res://game/core/ai/tasks/bt_away_from_post.gd")
const WalkHome = preload("res://game/core/ai/tasks/bt_walk_home.gd")
const FollowLeader = preload("res://game/core/ai/tasks/bt_follow_leader.gd")
const RunPlan = preload("res://game/core/ai/tasks/bt_run_plan.gd")
const CollectLoot = preload("res://game/core/ai/tasks/bt_collect_loot.gd")
const SellLoot = preload("res://game/core/ai/tasks/bt_sell_loot.gd")
const PATH: String = "res://game/data/bot_behavior.tres"


static func build() -> BehaviorTree:
	var tree := BehaviorTree.new()
	tree.description = "Brimholt player bot: dummies idle; others use resources, fight a target, collect their group's loot, sell it at a vendor, follow their leader, run a rival errand, or walk back to their post."
	var root := BTSelector.new()
	root.custom_name = "Bot"
	var dummy := BTSequence.new()
	dummy.custom_name = "Training dummy"
	var stance: BTCondition = IsStance.new()
	stance.set("stance", "dummy")
	dummy.add_child(stance)
	root.add_child(dummy)
	var play := BTSequence.new()
	play.custom_name = "Play"
	play.add_child(UseResources.new())
	var choose := BTSelector.new()
	var fight := BTSequence.new()
	fight.custom_name = "Fight"
	fight.add_child(PickTarget.new())
	fight.add_child(Engage.new())
	choose.add_child(fight)
	choose.add_child(CollectLoot.new())
	choose.add_child(SellLoot.new())
	choose.add_child(FollowLeader.new())
	var errand := BTSequence.new()
	errand.custom_name = "Rival errand"
	var rival: BTCondition = IsStance.new()
	rival.set("stance", "rival")
	errand.add_child(rival)
	errand.add_child(RunPlan.new())
	choose.add_child(errand)
	var home := BTSequence.new()
	home.custom_name = "Return to post"
	home.add_child(AwayFromPost.new())
	home.add_child(WalkHome.new())
	choose.add_child(home)
	play.add_child(choose)
	root.add_child(play)
	tree.root_task = root
	return tree


## The saved tree (editable in the LimboAI editor), else a freshly built one.
static func load_tree() -> BehaviorTree:
	if ResourceLoader.exists(PATH):
		var saved: Resource = load(PATH)
		if saved is BehaviorTree:
			return saved
	return build()
